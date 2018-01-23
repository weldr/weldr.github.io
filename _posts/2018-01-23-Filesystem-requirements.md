---
layout: post
title: File system as a requirement
author: dshea
---

The file system--a tree-like representation of file data and metadata--is a
necessary component of any export from RPM data, even if the export is not to a
file system. There are two reasons for this: directory permissions, and symlinks.

## Writing to the unwritable: read-only directories and their children

Let's suppose we have a list of files to write that looks like the following:

```
dr--r--r-- dshea dshea  0 Jan 22 17:00 /dir
-rwxr-xr-x dshea dshea 47 Jan 22 17:00 /dir/file-one
-rwxr-xr-x dshea dshea 47 Jan 22 17:00 /dir/file-two
```

If we were to write these entries to the file system in order, we might
do something like:

   * mkdir("/dir", 0400), utimes("/dir", ...)
   * creat("/dir/file-one", 0755), write(), utimes("/dir/file-one")
   * creat("/dir/file-two", 0755), write(), utimes("/dir/file-two")

The problems with this approach are 1) creating /dir with the final mode means that
the files underneath /dir cannot be written, and 2) writing the files beneath
/dir will change the modification time of /dir.

RPM itself handles the first issue by requiring everything to run as root, and
the second by mostly ignoring it and letting package installs update mtimes.

For other archive formats, this issue is handled by creating directories as writable
regardless of the archive mode, and then calling chmod() and utimes() (or equivalent)
after the directory contents have been written. This often creates an expectation for
the order of members within an archive. In the case of GNU tar, it will defer the
directory time and permissions until it sees an archive member that is not under /dir.
This means that if we create an archive that looks like:

```
-r--r--r-- dshea dshea  0 Jan 22 17:00 /dir
-rwxr-xr-x dshea dshea 47 Jan 22 17:00 /dir/file-one
-rwxr-xr-x dshea dshea 47 Jan 22 17:00 /dir/file-two
-r--r--r-- dshea dshea  0 Jan 22 17:00 /not-dir
-rwxr-xr-x dshea dshea 47 Jan 22 17:00 /dir/file-three
```

tar will call chmod() and utimes() on /dir when it sees the /not-dir archive member,
and then /dir/file-three will cause an error since /dir is no longer writable.

When exporting RPM data to other formats, that means we must build a tree of all
paths across all packages to be exported before creating a new archive. For example,
let's create an archive containing the filesystem package (which includes the metadata
for /usr/bin) and the sed package (which includes /usr/bin/sed). We can use the bsdtar
utility from libarchive to naively concatenate the rpms into a single archive:

```
$ rpm2cpio filesystem-3.3-3.fc27.x86_64.rpm | bsdtar -rf export.tar @-
$ rpm2cpio sed-4.4-3.fc27.x86_64.rpm | bsdtar -rf export.tar @-
```

The resulting archive looks like something like:

```
dr-xr-xr-x 0/0               0 2017-08-02 19:32 ./
...
drwxr-xr-x 0/0               0 2017-08-02 19:32 ./usr/
dr-xr-xr-x 0/0               0 2017-08-02 19:32 ./usr/bin/
drwxr-xr-x 0/0               0 2017-08-02 19:32 ./usr/games/
...
-rwxr-xr-x 0/0          112328 2017-08-04 15:28 ./usr/bin/sed
drwxr-xr-x 0/0               0 2017-08-04 15:28 ./usr/lib/.build-id/
...
```

And if we try to extract it with GNU tar, we get a bunch of error messages.

```
$ mkdir root
$ cd root
$ tar xf ../export.tar
tar: ./usr/bin/sed: Cannot open: Permission denied
tar: ./usr/lib/.build-id: Cannot mkdir: Permission denied
tar: ./usr/lib/.build-id: Cannot mkdir: Permission denied
tar: ./usr/lib/.build-id/c0: Cannot mkdir: No such file or directory
tar: ./usr/lib/.build-id: Cannot mkdir: Permission denied
tar: ./usr/lib/.build-id/c0/8415a86fe3105b454a8ee6cd878d5ff679237e: Cannot open: No such file or directory
tar: Exiting with failure status due to previous errors
```

In order to build a portable archive from these two packages, we need to create a file system
tree containing all of the paths to be exported, and use this tree to determine the order in
which to export the paths. In the case of tar, the paths need to be exported in a depth-first,
pre-order traversal.

As an aside, GNU tar includes an option --delay-directory-restore that will delay the chmod()
and utimes() calls until the end of the archive, instead of performing them as soon as possible.
Delaying the directory permissions and times until the end of the archive is also the default
behavior of bsdtar. So it is sometimes possible to use archives with unordered entries, but it
makes some assumptions about the behavior of the archive consumer.

## Symlinks

Symbolic links really tear things up, and there's not an easy way to work around them. The problem,
briefly, is that because RPMs can contains symlinks, and because RPMs are more or less self-contained,
unaware of the context into which they will be installed beyond what is expressed in the dependency
graph, any package can modify the paths of any other package.

### UsrMove and some examples

[UsrMove](https://fedoraproject.org/wiki/Features/UsrMove) was a feature introduced in Fedora 17 to
reduce redundancy in the file system. Historically, utilities and libraries necessary to initialize
the system, which may have included mounting /usr, were present in the top-level /bin, /sbin, and /lib
directories. The use of initramfs files for the boot process made these top-level directories
unnecessary, so the contents were moved to the corresponding directories under /usr. In place of the
top-level directories, symlinks to /usr were installed so that existing references to /bin, /lib, etc.
would continue to work. For example, nearly every shell script in the world expects to find /bin/sh,
so /bin/sh needs to continue to work even after the shell has been moved to /usr/bin/sh.

The top-level symlinks solved the problem of file system references to pre-UsrMove paths, but did not
address the problem of RPM requirements for pre-UsrMove paths. An RPM package can require a path on
the file system. For example, `Requires: /bin/cp` This requirement can be resolved in one of two ways:
a package can include this path in its list of files, or a package can include this path in its
ProvideName metadata.

The Fedora UsrMove feature did not include guidance for packagers, so packages that contained pre-UsrMove
paths in /bin, /lib, and /sbin reacted in several ways.

#### Crud up the Provides

The most backwards-compatible thing to do was to simply add the old paths to the RPM provides. This is
what coreutils did. In Fedora 16, coreutils installed several utilities to /bin. In Fedora 17, the
coreutils installed utilities only to /usr/bin, and the Provides data for coreutils included most of the
old /bin paths.

```
$ rpm -qlp coreutils-8.12-2.fc16.x86_64.rpm
/bin/arch
/bin/basename
/bin/cat
...

$ rpm -qlp coreutils-8.15-6.fc17.x86_64.rpm
...
/usr/bin/arch
/usr/bin/base64
/usr/bin/basename
/usr/bin/cat
...

$ rpm -qp --provides coreutils-8.15-6.fc17.x86_64.rpm
/bin/basename
/bin/cat
...
```

Packages that require, for example, /bin/cat, will continue to work across the UsrMove.

#### It's not my problem, it's your problem

Another way to deal with the move is to not deal with it at all and break backwards compatibility.
This is what ntfsprogs did. In Fedora 16, ntfsprogs installed its utilities to /bin and /sbin. In
Fedora 17, ntfsprogs moved its utilities to /usr/bin and /usr/sbin, and added nothing to the its
Provides. Any package that depended on the pre-UsrMove /bin or /sbin paths would need to update
in order to continue to work.

```
$ rpm -qlp ntfsprogs-2011.4.12-5.fc16.x86_64.rpm
/bin/ntfscat
/bin/ntfsck
/bin/ntfscluster
...

$ rpm -qlp ntfsprogs-2012.1.15-1.fc17.x86_64.rpm
/usr/bin/ntfscat
/usr/bin/ntfsck
/usr/bin/ntfscluster
...

$ rpm -qp --provides ntfsprogs-2012.1.15-1.fc17.x86_64.rpm 
ntfsprogs-gnomevfs = 2:2012.1.15-1.fc17
ntfsprogs = 2:2012.1.15-1.fc17
ntfsprogs(x86-64) = 2:2012.1.15-1.fc17
```

#### It's not my problem, it's the file system's problem

This is the fun one. A package could also choose to do literally nothing at all. Do not update
provides. Do not update paths. Continue to install to /bin, /lib, etc. As long as the UsrMove-installed
symlinks are in place, package installs and upgrades will correctly use the new /usr paths. RPM
metadata can all continue in its pre-UsrMove state.

```
$ rpm -qlp grep-2.9-3.fc16.x86_64.rpm
/bin/egrep
/bin/fgrep
/bin/grep
...

$ rpm -qlp grep-3.1-3.fc27.x86_64.rpm
/bin/egrep
/bin/fgrep
/bin/grep
...
```

### Implicit file system dependencies

One thing demonstrated by the grep case is that packages have implicit dependencies on the
packages that provides their parent directories. In order to correctly install /bin/grep,
/bin needs to be installed. When installing packages, RPM will automatically create missing
parent directories, but this is dangerous. The parent directory might not be a directory.

```
# mkdir root
# rpm -i --root $PWD/root --nodeps --noscripts grep-3.1-3.fc27.x86_64.rpm
# ls -l root/
total 0
drwxr-xr-x 2 root root 44 Jan 23 12:51 bin
drwxr-xr-x 3 root root 42 Jan 23 12:51 etc
drwxr-xr-x 5 root root 45 Jan 23 12:51 usr
drwxr-xr-x 3 root root 17 Jan 23 12:51 var
```

If we were to install the filesystem package, which provides the top-level symlinks, after
installing grep, we will get an error. filesystem will be unable to create the /bin symlink
since there is already a /bin directory in the way.

```
# rpm -i --root $PWD/root --nodeps --noscript filesystem-3.3-3.fc27.x86_64.rpm
error: unpacking of archive failed on file /bin: cpio: File from package already exists as a directory in system
error: filesystem-3.3-3.fc27.x86_64: install failed
```

This particular case is actually handled by RPM dependencies, and it's super fragile.

In Fedora 27, the minimum set of RPMs needed to install grep is 20 packages. The dependency
graph looks something like this:

![grep dependency graph](/images/grepdep.png)

Simple. There are two paths that pull in the filesystem package, which is what we need for those
important top-level symlinks. The grep -> bash -> filesystem path is mostly an accident. grep
requires bash to run its package scripts, and, even though RPM stores script dependencies
separately, it always evaluates them whether they are needed or not. glibc -> basesystem -> filesystem
is the important path. It's assumed that glibc will be at or near the bottom of any dependency graph,
so in order to provide a base environment glibc depends on basesystem, and basesystem depends on the
directories and symlinks that make up the core of the system.

When installing packages, RPM will break cycles in the dependency graph to form a DAG and tsort the
result, in an attempt to install packages in dependency order. When installing these 20 packages as
a set, filesystem will be installed early, and grep will be installed last. So, for the case of
packages that depend on symlinks in the filesystem package, you're covered by a lot of dependency
arcana and little bit of persistent luck. For anything else, you'll have to come up with your own
solution.

### Symlinks and other export types

There is enough information in RPM metadata to order a transaction such that the file system can resolve
paths to the correct location. When exporting RPM data to something other than a file system, however, this
is not enough.

When exporting to a tar file, for example, the consumer of the tar file may not be able to handle the /bin
paths when /bin is not a directory, regardless of the order the archive members.

```
# rpm2cpio filesystem-3.3-3.fc27.x86_64.rpm | bsdtar -rf export.tar @-
# rpm2cpio grep-3.1-3.fc27.x86_64.rpm | bsdtar -rf export.tar @-
# ostree init --repo=repo --mode=bare
# ostree commit --repo=repo --branch=example --tree=tar=export.tar
error: No such file or directory: bin
```

This means that exports of RPM data to archives need to implement a file system, even if the final target
is not a file system. The export process needs to be able to resolve symlink paths to real path, across
multiple packages, in order to create an archive that is internally consistent.

A file system is always required in order to describe RPM data, even if the files are not being written
to a file system. In order to aggregate the data from multiple packages into an internally consistent
archive, we need to be able, at the least, to order files and directories in a depth-first fashion, and
to resolve symlinks to directories to the actual, final directories.
