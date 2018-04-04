---

layout: post
title: "Unpacking RPM: an introduction"
author: wwoods
tags: unpacking-rpm rpm fedora

---

(tl;dr version: let's start mapping out the RPM ecosystem as a whole - from
high-level abstractions and use cases down to the bits and bytes - so we can
make improvements and build the software ecosystem we really want.)

Hi! I'm Will Woods, and today I want to talk about... RPM.

_[crowd boos, throws tomatoes]_

I know, I know, everyone who's talked to me at all in the past five years is
sick of hearing me talk about RPM. But bear with me for a moment, because I
think this is important.

Nearly everything we do in Fedora (and, by extension, in RHEL and CentOS)
revolves around RPM. We've built entire software ecosystems around it:

* [up2date] and [yum] and [dnf] to resolve deps and download packages,
* [createrepo] and [mirrormanager] to manage and distribute repos,
* [fedpkg] and [dist-git] and the [lookaside cache] to help us build SRPMs,
* [pkgdb] and [pagure] to manage permissions and ownership of each package,
* [koji] and [mock] to make RPM building more reliable,
* [anaconda], [lorax], [pungi], [livemedia-creator] and so on for installs and
  image builds,
* [PreUpgrade], [fedup] and [dnf system-upgrade] for system upgrades,
* [bodhi] for managing manual update testing,
* [autoqa] and [taskotron] for automated testing,
* [comps.xml], [AppStream], [Modularity], and [Software Collections] to
  provide extended package metadata and handle variant builds

..and so on and so forth. There's a _lot_.

Here's the thing: **RPM wasn't designed for any of this**.

RPM was designed in the the mid-1990s, a faraway time when dial-up internet,
floppy disks, and single-speed CD-ROM drives were the norm and source code was
released by putting a tarball on the project's FTP server.

Red Hat Linux 4.2 for i386 consisted of 459 RPMs - a big jump from the 387
packages available in RHL 3.0.3. (Fedora 27 for `x86_64` currently has
_66,913_ packages, including updates.)

There's a lot more to talk about here, but the overall point is: typical
use-cases for the RPM ecosystem _today_ are very different - orders of
magnitude different - than when the tools and file formats were originally
designed. A lot has changed over the years, and we've done some extremely
clever (and some extremely ugly!) things to keep everything up and running,
and to get it to handle all the new use cases that keep coming up.

So. It all _works_, at least. But are we sure that it works _well_?

Most projects keep their sources in git repos, but we're still building RPMs
from hand-imported tarballs and patches - the same way we've done it
since 1997. Nobody _loves_ dealing with patches and tarballs, but since it
seems too hard (or too "drastic") to change RPM to work the way we'd like, we
just do what we always do:

1. Shrug and hope The Community will deal with it
1. Write and maintain custom one-off tools to handle the hard parts (like
   [texlive] does)
1. Build other tools that work around the problem by adding another layer of
   code and metadata ([mock-scm], [tito], [gofed], and so on)

I think we can do much, much better. There's a lot of room for improvement in
nearly every aspect of the RPM ecosystem. I think the [problems we've been
having with Modularity] and [32-hour "nightly" composes] suggest that we may
have pushed parts of this system to its limits - or at least to a point where
we can't fix the problems by just adding another layer of code and metadata.

If we want to make the system work better, _we need to understand how it
works_.  We need to look past _what_ it's doing to _why_: what is the intent?
What are the problems that users are trying to solve?  And are we giving them
good tools to solve those problems?

I think we need to look at the _entire_ system, inside and out, from upstream
sources to built images, and document how it all works at an abstract level:
What are the most important tasks and use cases? What are the inputs and
outputs? How do all the pieces interact? How do people actually _use_ this
stuff, here in the year 2018?

Once we understand how each part works and how they interact with each other,
we can start designing improvements - or replacements - that work the way we
_want_ our software build ecosystem to work. Reproduceable builds? Sure!
Atomic updates with rollback? That too! New metadata, like `TestRequires`?
Absolutely!

All we have to do, in my opinion, is keep asking ourselves three questions:

1. **What is this part of the system actually trying to do?**
2. **If we designed something to do this today, what would it look like?**
3. **How do we get there from here?**

This is the basic framework for what we've been doing inside Project Weldr so
far, and it seems to be working pretty well for us. I've given a couple of
talks about one particular part of the system - [RPM scriptlets] - and
rethinking that piece made us able to build bootable images _100x faster_ than
the existing tools. And we're just getting started.

----------------

Next post: [RPM package names]!

[RPM scriptlets]: https://www.youtube.com/watch?v=kE-8ZRISFqA#t=2m33
[up2date]: https://en.wikipedia.org/wiki/Up2date
[anaconda]: https://en.wikipedia.org/wiki/Anaconda_(installer)
[pungi]: https://pagure.io/pungi
[lorax]: https://github.com/rhinstaller/lorax
[preupgrade]: https://fedoraproject.org/wiki/How_to_use_PreUpgrade
[fedup]: https://fedoraproject.org/wiki/FedUp
[DNF]: https://en.wikipedia.org/wiki/DNF_(software)
[createrepo]: https://github.com/rpm-software-management/createrepo
[dnf system-upgrade]: https://fedoraproject.org/wiki/DNF_system_upgrade
[Software Collections]: https://www.softwarecollections.org/en/docs/guide/
[dist-git]: https://fedoraproject.org/wiki/Package_Source_Control
[lookaside cache]: https://fedoraproject.org/wiki/Package_Source_Control#Lookaside_Cache
[fedpkg]: https://fedoraproject.org/wiki/Package_maintenance_guide
[Modularity]: https://docs.pagure.org/modularity/
[AppStream]: https://www.freedesktop.org/software/appstream/docs/
[koji]: https://fedoraproject.org/wiki/Koji
[mirrormanager]: https://fedoraproject.org/wiki/Infrastructure/MirrorManager
[mock]: https://github.com/rpm-software-management/mock/wiki
[yum]: https://en.wikipedia.org/wiki/Yellow_Dog_Updater,_Modified
[livemedia-creator]: https://weldr.io/lorax/livemedia-creator.html
[bodhi]: https://fedoraproject.org/wiki/Bodhi
[comps.xml]: https://fedoraproject.org/wiki/How_to_use_and_edit_comps.xml_for_package_groups
[pkgdb]: https://admin.fedoraproject.org/pkgdb
[pagure]: https://src.fedoraproject.org/
[autoqa]: https://pagure.io/fedora-qa/autoqa
[taskotron]: https://taskotron.fedoraproject.org/
[tito]: https://github.com/dgoodwin/tito
[mock-scm]: https://github.com/rpm-software-management/mock/wiki/Plugin-Scm
[gofed]: https://github.com/gofed/gofed/
[COPR]: https://copr.fedorainfracloud.org/
[problems we've been having with Modularity]: https://www.phoronix.com/scan.php?page=news_item&px=Fedora-27-Server-Classic
[32-hour "nightly" composes]: https://bugzilla.redhat.com/show_bug.cgi?id=1551653
[texlive]: https://src.fedoraproject.org/rpms/texlive/blob/master/f/tl2rpm.c
[RPM package names]: {% post_url 2018-04-02-Unpacking-RPM-names %}
