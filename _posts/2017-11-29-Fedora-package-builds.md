---
layout: post
title: How the heck do you build a Fedora package these days
author: dshea
---

Let's say you have some content that you want included in Fedora. Let's say you
used to know how to do that, but now everything is different and weird. What's
going on, anyway? How does anything work?

## Prerequisites

### Fedora account stuff

If you are not already a Fedora package maintainer, you will need to go through
some steps to become one. You'll need a Fedora Account System (FAS) account, a
Red Hat Bugzilla account, and you will need someone to sponsor you as a Fedora packager.
The details of this process are described on the [Fedora wiki](https://fedoraproject.org/wiki/Join_the_package_collection_maintainers).

### System stuff

Install the `fedora-packager` package. This includes the tools you need to use
bodhi and koji, as well as a configuration file for Kerberos authentication. If you have modified your system's
/etc/krb5.conf file, make sure it includes a line `includedir /etc/krb5.conf.d/` in order to use the configuration
file added by Fedora.

Install the `fedrepo-req` package. This isn't included in the fedora-packager dependencies for some reason.

If you don't already have the certificate files needed for Koji, generate them by running `fedora-packager-setup`.

Most parts of the package process now use Kerberos for authentication, so run `kinit <username>@FEDORAPROJECT.ORG`.

## Package review

The Fedora package review process is described on the [wiki](https://fedoraproject.org/wiki/Package_Review_Process).
If you have submitted a package in the past, the process is basically the same
up until the point when you're ready to create the dist-git repo. In short:

   * Upload a spec file and a SRPM somewhere
   * Fill out the [template](https://bugzilla.redhat.com/bugzilla/enter_bug.cgi?product=Fedora&format=fedora-review)
   * Work with the reviewer to get your package into an acceptable state
   * If everything goes ok the reviewer will set `fedora-review+` in Bugzilla.

## dist-git repo creation

After the package has been approved, it's time to create the repo in dist-git. This repo is where the spec file, patches,
and a description of the source files are kept. Fedora recently moved all of the dist-git repos to a Pagure instance at
[https://src.fedoraproject.org/](https://src.fedoraproject.org/), and repo actions are now handled through Pagure instead
of Bugzilla.

dist-git actions are done via Pagure tickets, which are created via
`fedrepo-req` and `fedrepo-req-branch`, which, annoyingly, do not authenticate
via Kerberos. Configure `fedrepo-req` by doing the following:

   * Go to [https://pagure.io/settings](https://pagure.io/settings). This is a different Pagure than the one with all the dist-git repos. I don't know why.
   * Login with your FAS account when prompted
   * Click "Create new key" under the "API Keys" box
   * Add a description
   * Check "Create a new ticket" under the ACLs list.
   * Create
   * Scroll back down to "API Keys", copy the token you just created to the clipboard
   * Create a file `~/.config/fedrepo_req/config.ini` that looks like this:

   ```
   [app]
   pagure_api_token = <token>
   ```

NB: The API token is only good for 60 days.

To request a new repo, run `fedrepo-req <package name> -t <bugzilla id>`, where
"bugzilla id" is the ID of the package review bug. Fedora releng will process
the ticket at some point. It's usually pretty quick.

New repos will only have a "master" branch, which corresponds to rawhide. To create branches for Fedora or
EPEL releases, use `fedrepo-req-branch <package-name> <branch-name>`, where branch name can be something like
"f26" or "epel7".

## dist-git repo population

After your repo is created, run `fedpkg clone <package name>`. Add your spec file and any patches that the spec file needs.
For source files, run `fedpkg new-sources <Source0> [<Source1> ...]`. This will upload the source files to Fedora, create a
"sources" file with the filenames and checksums, and stage the "sources" file for commit.

When you're ready, commit and push. You can do this via the fedpkg tool, or you can just use git. Repeat for any release
branches you want to use.

## Package build

Fedora packages are built in [Koji](https://koji.fedoraproject.org/koji/), and fedpkg provides the interface to it. When you
want to build a package, change to the directory of your dist-git clone, checkout the branch you want to build for, and run
`fedpkg build`. This will build whatever has been pushed to the repo on src.fedoraproject.org.

If you want to test that a package builds before pushing, you can run a scratch build. Create a SRPM with `fedpkg srpm`, and
then run `fedpkg build --scratch --srpm <srpm file>`.

## Fedora update

If you are building for rawhide, any package you build will automatically be
included in the next rawhide repo. For branched versions of Fedora, you will
need to create an update in [Bodhi](https://bodhi.fedoraproject.org/).

From your dist-git repo, run `fedpkg update`. This will open a text editor with
a template to fill out. Fill it out, save and quit, and enter your FAS password
if prompted because of course this uses a different authentication method than
anything else we've used so far.

Once your update has been created, the package will be included in the next
updates-testing repo. After your update has received the appropriate amount of
Karma points from tests, or after it has sat around for an appropriate amount
of time, you can push a button on the Bodhi website to push the package to
"batched", which will include it in the next weekly Fedora update.

You can also create an update on the website, which you will need to do if
updating more than one package at a time, as described below.

## What if I have packages that depend on other packages?

The Fedora update system takes a couple weeks or so before a package will be
included in the next stable repo. Koji only includes packages in stable. So how
do you build packages that depend on other packages not yet in stable?

### A quick overview of koji's guts because no one else actually explains any of this

Everything in koji is based around buildroots and tags. Both buildroot and tag
are different words for a yum repo.  When you build a package in koji, it will
install packages to satisfy the BuildRequires lines in your spec file, and the
packages that are available for this install are defined by the tag.

In general, the packages available for builds (the build tag, e.g. f26-build)
are whatever is in the stable repo.  For branched releases, newly built
packages start out with a candidate tag.  Candidate packages are not included
in the build tag until they have been pushed to stable by Bodhi.

### rawhide

In rawhide, there is no update delay. After a package is built, it is added to
the rawhide tag, and as soon as Koji finishes regenerating a repo for the tag,
the package is available for subsequent builds.

`fedpkg chain-build` is available to automate the step of waiting for the next repo.
The argument list to chain build is a list of packages to build in parallel, followed by
a colon, followed by the next list of packages. The package corresponding to your current
working directory is added to the end of the argument list, so if you don't want it built
in parallel with the last list of packages you need one last colon.

Every package name needs to be prefixed with "rpms/", because every package's dist-git
URL has an rpms/ path and chain-build doesn't know about it for some reason.

For example, `fedpkg chain-build rpms/pkgA rpms/pkgB \: rpms/pkgC \:` will build pkgA and pkgB
in parallel, wait for them to show up in the repo, build pkgC, wait for it to show up in the repo,
and then build the package in the current directory.

### branched

The chain-build command does not work in branched releases. Instead, you need to create a buildroot
override, which will temporarily add a package to the build tag in koji.

Buildroot overrides are created via Bodhi. Go to the [Bodhi page](https://bodhi.fedoraproject.org/).
Click "Create" up at the top, and then click "New Override" in the menu. Under candidate build,
input the NEVR of the package that you want to build against; e.g., "ghc-servant-0.12-1.fc26".
The "Buildroot override notes" is just a text field to describe the purpose of the override, and
the expiration date is how long the override will last. Once that's created, Bodhi will give you
a Koji command to run that will wait for the new repo to be created for the override, something
like `koji wait-repo f26-build --build=ghc-servant-0.12-1.fc26`. Run that, and after it returns you
can do normal `fedpkg build` commands.

If you're doing builds with buildroot overrides, you probably want all of the packages involved
to be in the same Bodhi update. You can do this, but you have to create an update via the website
instead of via `fedpkg update`. Click "Create", then "New Update", then add the package NEVRs under
"Candidate Builds" and the review bugs under "Related Bugs".

There is a bodhi command-line client for creating updates and overrides, but Fedora wiki pages
suggest that it does not actually work.

Buildroot overrides can use any package marked as a candidate (just built) or
testing (started the update process). If you are trying to build against a
package that has been marked as stable in Bodhi but has not yet reached the
actual stable repo, you'll just have to wait.

And there you have it, a package, or several.
