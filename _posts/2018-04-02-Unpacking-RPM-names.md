---

layout: post
title: "Unpacking RPM: package names"
author: wwoods
tags: rpm fedora packaging unpacking-rpm

---
Have you ever noticed that Fedora keeps getting bigger and package names keep
getting.. gnarlier? Let's have a look!

Here's some data I gathered about the number of RPMs in
each Fedora release[^1] and the average, median, and longest package names:

```
Version  | Total RPMs | avg / med | max | Longest package name(s)
---------+------------+-----------+-----+-------------------------------------------------
Fedora  1:  1477 RPMs,  10.1 /  9,   31: XFree86-ISO8859-14-100dpi-fonts, redhat-config-securitylevel-tui
Fedora  2:  1647 RPMs,  10.4 / 10,   32: xorg-x11-ISO8859-14-100dpi-fonts
Fedora  3:  1883 RPMs,  10.3 / 10,   31: selinux-policy-targeted-sources, system-config-securitylevel-tui
Fedora  4:  1981 RPMs,  11.4 / 10,   35: jakarta-commons-collections-javadoc
Fedora  5:  2422 RPMs,  11.8 / 11,   35: jakarta-commons-collections-javadoc
Fedora  6:  2931 RPMs,  12.3 / 12,   49: jakarta-commons-collections-testframework-javadoc
Fedora  7:  9334 RPMs,  12.3 / 12,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora  8: 10657 RPMs,  12.4 / 12,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora  9: 12444 RPMs,  12.5 / 12,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 10: 14303 RPMs,  12.6 / 12,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 11: 16577 RPMs,  12.8 / 12,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 12: 19122 RPMs,  13.2 / 12,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 13: 20840 RPMs,  13.4 / 13,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 14: 22161 RPMs,  13.5 / 13,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 15: 24085 RPMs,  13.6 / 13,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 16: 25098 RPMs,  13.7 / 13,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 17: 27033 RPMs,  13.8 / 13,   50: php-pear-Structures-DataGrid-DataSource-DataObject
Fedora 18: 33868 RPMs,  14.6 / 14,   57: gnome-shell-extension-sustmi-historymanager-prefix-search
Fedora 19: 36253 RPMs,  14.7 / 14,   57: gnome-shell-extension-sustmi-historymanager-prefix-search
Fedora 20: 38597 RPMs,  14.9 / 14,   57: gnome-shell-extension-sustmi-historymanager-prefix-search
Fedora 21: 42816 RPMs,  15.0 / 15,   57: gnome-shell-extension-sustmi-historymanager-prefix-search
Fedora 22: 44762 RPMs,  15.2 / 15,   58: perl-Archive-Extract-tbz-Archive-Tar-IO-Uncompress-Bunzip2
Fedora 23: 46074 RPMs,  15.3 / 15,   58: perl-Archive-Extract-tbz-Archive-Tar-IO-Uncompress-Bunzip2
Fedora 24: 49722 RPMs,  15.6 / 15,   61: golang-github-matttproud-golang_protobuf_extensions-unit-test
Fedora 25: 51669 RPMs,  15.8 / 15,   61: golang-github-matttproud-golang_protobuf_extensions-unit-test
Fedora 26: 53912 RPMs,  16.0 / 15,   64: golang-github-cloudfoundry-incubator-candiedyaml-unit-test-devel
Fedora 27: 54801 RPMs,  16.1 / 15,   64: golang-github-cloudfoundry-incubator-candiedyaml-unit-test-devel
```

Sure enough:

1. Fedora gets bigger with every release (especially F7, when we [merged Core and
   Extras]), and
2. The average package name gets longer with every release.[^2]

OK, great. But _why_ do package names keep getting longer? Well, the proximate
cause seems obvious: after FC4, the longest names are all things that have
been repackaged from some other software packaging ecosystem:
[Jakarta]/[Apache Commons] for Java, [PEAR] for PHP, [Gnome Shell Extensions]
for [gnome-shell], Perl's [CPAN], and [golang]'s builtin module system.  So
we're mapping the other ecosystem's module namespace into RPM's (single, flat)
package namespace, and then adding a **prefix** to indicate which ecosystem it
came from.

Another thing that makes package names longer is subpackages, like
`-devel`, `-javadoc`, and `-unit-test` above. In these cases we're adding a
**suffix** to the package name to indicate that this part of the package is
only needed _for a particular purpose_. For example: `-devel` means "install
this if you're doing development", `-javadoc` means "install this if you want
to read Java documentation", `-unit-test` means "install this if you want to
run unit tests", etc.

So names keep getting longer because we keep adding suffixes and prefixes and
stuffing entire other software module namespaces into our package names. But
why do we have to cram everything into the names? Well, because _RPM only
looks at package names_[^3]. It doesn't consider any other metadata when
choosing between packages, even though there's plenty of other relevant data
you might _want_ to consider:

* Source software ecosystem: "this is a rubygem"
* Package build environment: "this was built using python3, not python2"
* Major-version API changes: "this can be installed in parallel with the new version"
* Package build options: "this was built with debugging turned on"
* File-level metadata: "these files are only needed for development"

And so on. RPM doesn't give us a way to add extended/new metadata, so we've
resorted to encoding all that metadata _in the package name_, with prefixes
and suffixes: `rubygem-`, `python3-`, `compat-`, `-debug`, `-devel`.

So! Let's take a swing at that first question from [the intro]:

## What's this actually trying to _do_?

To try to figure out what things people are _actually_ trying to accomplish
with ever-longer RPM names, let's look at the most commonly-used "words".

If you're on a Fedora system and you'd like to play along, here's a one-liner
that'll generate a list of words, sorted by number of occurrences:

```shell
dnf repoquery --qf '%{NAME}' --repo="fedora" --repo="updates" \
    | tr '-' '\n' | sort | uniq -c | sort -n | tac | less
```

I also wrote a [little script] to do slightly fancier analysis of the words in
RPM names - keeping word pairs like "`apache-commons`" as a single word,
counting each word's use as a prefix, as a suffix, and per-specfile[^4], and
labeling the "meaning" of common words.

Here's the results from that:

{% capture csvdata %}
word,specfiles,rpms,as prefix,as suffix,meaning
devel,4410,5290,0,5197,file-type
perl,2953,3140,3073,61,package prefix
python3,1855,2053,2004,42,build-variant
doc,1704,4646,0,4615,file-type
python2,1536,1731,1699,12,build-variant
javadoc,1241,1253,0,1243,file-type
nodejs,1129,1399,1398,0,package prefix
python,1069,1210,1043,125,programming language
rubygem,635,1261,1261,0,package prefix
php,620,861,825,10,programming language
golang,465,951,919,0,package prefix
github,444,838,0,1,
libs,436,523,0,479,file-type
ghc,433,1055,1044,1,package prefix
unit-test,413,414,0,189,file-purpose
common,327,374,1,309,core/extras
fonts,323,845,4,750,file-type
tools,303,413,0,321,file-purpose
plugin,290,725,0,264,extends/enhances
static,264,417,0,413,build-variant
mingw32,229,392,392,0,build-variant
mingw64,217,377,377,0,build-variant
utils,196,264,0,205,file-purpose
Test,193,195,0,10,
gnome,164,240,165,67,environment
data,164,218,0,146,file-type
java,155,411,81,104,programming language
client,153,285,0,170,file-purpose
maven,148,349,256,4,framework
R,147,174,170,3,programming language
server,144,222,0,142,file-purpose
docs,141,160,0,141,file-type
core,139,243,0,158,core/extras
api,138,267,1,144,file-purpose
go,137,250,5,6,programming language
tests,136,173,0,170,file-purpose
rust,132,139,137,0,programming language
plugins,128,376,0,87,extends/enhances
hunspell,126,135,128,2,project name
kf5,126,278,277,1,framework
examples,125,142,0,132,file-purpose
qt5,117,358,159,60,framework
horde,112,114,0,2,project name
erlang,111,163,161,1,programming language
Net,105,106,0,0,
ocaml,105,216,209,4,programming language
parent,102,121,0,116,file-type
theme,101,150,0,99,file-type
Horde,100,100,0,0,
drupal7,99,100,99,0,project name
Plugin,95,107,0,3,
gtk,88,141,28,62,framework
Class,88,88,0,10,
Text,84,86,0,1,
File,83,84,0,5,
zendframework,80,80,0,1,framework
jboss,79,156,147,3,project name
gui,79,91,0,77,file-purpose
test,77,101,2,50,file-purpose
zend,76,76,0,0,framework
qt,76,176,48,71,framework
eclipse,76,213,210,1,project name
cli,75,97,2,67,file-purpose
Module,75,76,0,2,
MooseX,75,79,0,0,
django,72,150,0,6,framework
sugar,71,85,82,2,environment
XML,71,72,0,6,data format
is,70,71,2,14,
kde,69,194,130,47,environment
Data,68,68,0,4,
HTML,68,70,0,6,data format
base,67,131,0,85,core/extras
compat,67,108,45,43,build-variant
ruby,65,99,55,25,programming language
config,63,88,0,46,file-type
php-pear,62,62,61,0,package prefix
mysql,61,90,11,62,framework
Simple,61,63,2,47,
js,60,73,45,15,programming language
globus,60,150,148,2,project name
lua,58,89,60,16,programming language
CGI,58,58,0,2,
hyphen,56,125,58,1,
http,56,102,4,20,protocol
json,56,75,15,24,data format
Crypt,55,56,0,1,
Devel,54,66,0,1,
extras,53,115,0,44,core/extras
Catalyst,52,57,0,2,
openmpi,52,124,3,60,framework
emacs,51,79,64,12,project name
gap-pkg,51,53,53,0,package prefix
mpich,50,122,3,58,framework
xfce4,50,56,55,0,environment
lib,50,74,0,48,file-type
fedora,49,74,47,15,vendor
trytond,49,53,52,0,project name
php-pecl,48,57,57,0,package prefix
HTTP,48,55,0,7,
aspell,46,47,44,2,project name
util,44,68,0,27,file-purpose
filesystem,43,46,0,42,file-type
web,43,65,3,35,file-purpose
xorg-x11,41,75,75,0,project name
stream,40,41,2,28,concept
manager,40,64,0,27,file-purpose
apache-commons,39,92,92,0,project name
mate,38,67,45,22,environment
cache,38,58,0,35,file-purpose
octave,37,39,34,3,programming language
xml,37,62,16,22,data format
tcl,37,55,32,20,programming language
ldap,36,47,0,32,protocol
file,36,49,4,21,concept
glib,36,81,3,37,framework
postgresql,35,59,25,28,framework
demo,35,38,0,36,file-purpose
el,35,42,0,34,data format
system,34,88,24,7,concept
console,34,41,4,21,file-purpose
google,33,70,37,2,vendor
mono,33,68,40,2,programming language
jenkins,33,70,64,3,project name
vim,33,106,93,10,project name
gnome-shell,33,46,44,1,project name
Tiny,32,32,0,32,
extra,32,58,1,29,core/extras
XS,31,33,0,29,
gtk3,31,53,5,26,framework
backgrounds,30,184,0,29,file-type
sqlite,30,44,7,29,framework
selinux,30,36,7,29,framework
gtk2,30,52,6,23,framework
c,29,67,3,22,programming language
ibus,29,65,63,0,framework
agent,29,49,0,22,file-purpose
glassfish,28,101,98,0,project name
Parser,28,30,0,22,
parser,28,48,0,30,file-purpose
it,28,46,0,27,translation
qt4,27,45,3,28,framework
manual,27,27,0,26,file-purpose
runtime,27,44,0,24,file-purpose
log,26,37,0,21,file-purpose
gimp,25,45,40,4,project name
es,25,38,0,24,translation
driver,25,84,0,21,extends/enhances
sans,25,153,0,0,font-type
plexus,25,53,51,2,project name
plasma,25,56,48,2,framework
extensions,24,31,0,25,extends/enhances
fr,24,48,0,28,translation
sharp,24,46,0,23,programming language
de,24,45,0,24,translation
info,23,30,0,20,file-type
xfce,23,35,2,31,environment
debug,22,60,0,44,build-variant
daemon,22,59,0,23,file-purpose
modules,22,33,0,27,extends/enhances
ru,21,33,0,22,translation
felix,21,40,40,0,project name
cs,21,25,0,22,translation
coin-or,21,61,61,0,project name
jackson,21,51,47,1,project name
glite,21,39,39,0,project name
sblim,20,41,41,0,project name
pgsql,20,24,0,23,framework
i18n,20,70,0,21,translation
firmware,19,40,2,34,file-type
oslo,19,97,0,0,project name
lxqt,18,34,34,0,environment
libvirt,18,85,59,12,project name
module,18,86,2,19,extends/enhances
geronimo,17,35,35,0,project name
springframework,15,50,49,0,project name
nagios,15,82,74,3,project name
bin,13,189,0,185,file-type
NetworkManager,13,37,35,0,project name
jetty,13,76,75,0,project name
bridge,12,32,4,24,file-purpose
qpid,10,76,59,3,project name
yum,10,41,38,1,project name
bundle,9,24,0,21,file-type
gcc,9,94,73,5,project name
langpacks,8,87,80,7,translation
root,7,110,102,7,project name
babel,6,126,1,9,
pulp,6,47,34,0,project name
aws-sdk,6,80,71,2,project name
langpack,5,405,0,1,translation
libreoffice,5,153,152,0,project name
l10n,5,79,1,22,translation
geany,5,44,41,0,project name
boost,4,56,49,3,framework
qemu,4,59,55,3,project name
shrinkwrap,4,50,48,1,project name
google-noto,3,146,146,0,project name
fence,3,66,66,0,project name
collectd,3,74,66,0,project name
linux-gnu,3,92,0,91,build-variant
glibc,2,201,200,0,project name
asterisk,2,41,40,0,project name
pcp,2,100,95,4,project name
tesseract,2,114,107,2,project name
pst,2,164,0,1,
lodash,2,264,0,3,framework
arquillian,2,49,38,0,project name
uwsgi,1,98,96,1,project name
gb,1,88,0,0,translation
gcompris,1,42,41,0,project name
fawkes,1,73,72,0,project name
fusionforge,1,38,37,0,project name
soletta,1,36,35,0,project name
asterisk-sounds-core,1,90,90,0,project name
gambas3,1,92,92,0,programming language
gallery2,1,76,75,0,project name
opensips,1,59,57,1,project name
openrdf-sesame,1,74,74,0,project name
texlive,1,5946,5928,0,project name
vdsm,1,44,43,0,project name
autocorr,1,33,33,0,project name
{% endcapture %}
{% include csvtable.html data=csvdata height="480px"
   caption="Top 100 most common words/prefixes/suffixes in RPMs and specfiles (F27, x86_64)" %}
(full data set: [rpm-name-word-counts.csv])

Looking over this list, I'd say there's 4 main features that we're trying to
hack into RPM with all our name-mangling: namespaces, variant builds,
new package relationships & metadata, and extended file-level metadata.

### 1. Language/project/vendor namespace prefixes

As a wise man once observed, "Namespaces are one honking great idea --
let's do more of those!"[^5] Sure enough, the 10 most common prefixes are
our ad-hoc namespace markers for modules repackaged from the native packaging
systems of some popular programming languages: `perl`, `python`, `nodejs`,
`rubygem`, `ghc`, `golang`, and `php`. Oh, and `texlive`, which is kind of a
packaging system but also a 220,000-line `rpmbuild` stress test[^6].

Anyway, RPM doesn't _actually_ have a way to create separate namespaces for
things like that, so in reality every package gets crammed into one big heap
and the user gets to figure out the rest - which is why "github" now shows up
as the 15th most common word overall (thanks, golang!)

This also means that regardless of whether or not it uses `texlive` or Node.js or
Ruby or Haskell or whatever, every Fedora system in the world still downloads
complete metadata for all 10,000+ of those packages every time it runs DNF.
Yikes.

One other note: `python2` and `python3` are actually pulling double duty.
They're _kinda_ language prefixes, but they're _also_ variant-build markers!

### 2. Parallel-installable variant builds

There's a lot of times that we want multiple variant builds of a project to be
available and/or parallel-installable, but we can't do that without modifying
the RPM name.

Most commonly, we want to build the same source tarball more than once, using
a different toolchain or build options. Since RPM doesn't care about the build
environment or build options when comparing packages, we have to change the
name to make RPM consider them different builds - and that's where we get
`-debug`, `-static`, `python2-`/`python3-`, `-qt4`/`-qt5`,
`mingw64-`/`mingw32-`, and so on.

Other times we're building two different _versions_ of the same sources -
usually the newest one and an older one that's required by some other package.
RPM technically allows you to install multiple versions of the same package
(as long as the package contents don't overlap) _but_ the default behavior (as
enforced by yum and dnf) is to _replace_ older versions of packages with newer
ones. So rather than dealing with that, we add `-compat` or `compat-` to the
older version to change its name, thus making RPM consider it a different
package.

Interestingly, it seems like we're not consistent in whether variant markers
are prefixes (like `python2-` and `mingw64-`) or suffixes (like `-debug` or
`-static`). Which isn't surprising - we're using these words in ways that are
human-meaningful, not machine-parseable, so naturally we use them in ways that
mirror human language.

In fact, as we see with `python` and friends: when a programming language name
is used as a _suffix_, it typically has a different meaning: `python-foo` is
probably "foo" (written in Python), but `foo-python` is probably Python
bindings to "foo". We're using the package name to provide (informal)
information about the relationship between two packages.

It turns out we do a lot of this!

### 3. New package relationships & metadata

Sure, we have soft dependencies now, but we still use a lot of unwritten
conventions that _imply_ certain relationships between projects. One
interesting example is the different ways we use `plugin`/`plugins` - there's
different "phrasings" that can have slightly different meanings:

* _PROJ-plugin-NAME_: A plugin for _PROJ_ named _NAME_ -
  `yum-plugin-versionlock`, `gedit-plugin-commander`, `uwsgi-plugin-zergpool`
* _PROJ-plugin-THING_: A plugin for _PROJ_ to handle/support _THING_ -
  `gedit-plugin-git`, `uwsgi-plugin-v8`, `abrt-plugin-bodhi`
* _PROJ-THING-plugin_: Java software seems to prefer this order -
  `maven-stapler-plugin`, `jenkins-ldap-plugin`
* _PROJ-plugins-GROUP_: A named _GROUP_ of plugins for _PROJ_:
  `dnf-plugins-core`, `gstreamer-plugins-good`, `gedit-plugins-data`,

Sometimes you just get an opaque NAME that suggests something about the
purpose of the plugin, sometimes the THING is a concept or protocol, like
`ldap`, and sometimes it's a specific piece of software, like `git` or
`stapler`. These would all be useful pieces of data for packaging software to
have! But instead we can only pick one of those pieces of data, and then we
encode it into the RPM name in a way that's _not machine-readable_. Wouldn't
it be nice if these relationships were formalized, and also maybe we could
store that metadata somewhere other than the package name?

You could argue that the informal metadata provided by `plugin`/`plugins`
could be formalized using the `Enhances:` or `Supplements:` RPM tags, but
there's plenty of other examples where we're using naming conventions to
establish similar informal relationships between packages and higher-level
concepts, like projects or languages - or basic concepts like `web` and `gui`.

I think this is one of the fundamental shortcomings of RPM's dependency
system: the only thing it lets you express easily is whether a given package
_requires_ another package[^7] when installed[^8]. It has no inherent concept
of anything other than a package, or of different sub-parts of a package, or
of any purpose for those parts other than installation.

And that's what we use subpackages for!

### 4. File-level metadata / tags and purposes

So! If we want to talk about something other than the entire build output, we
have to divide it into subpackages. If we need to talk to RPM about one
specific file, we have to put it into its own subpackage[^9].

When we break a build into subpackages, we're usually doing it because part of
the build is "optional" - that is, it's not required for the default assumed
"purpose", which is basically "runtime".

So to differentiate these "optional" parts from the "main" part, we once again
turn to.. RPM name mangling!

Sometimes - most commonly - we mark the parts by what _type_ of file they are:
`-devel`, `-doc`, `-javadoc`, `-help`. Or we mark the _purpose_ of those
files: `-tools`, `-utils`, `-unit-test`.

Now, _most_ systems probably don't need unit tests installed. But what about
documentation and help files? Or development headers? Alas, since RPM has no
concept of file types or purposes, we have no way to tell it what kind of
parts we might want - and so we have to manually install `-doc` and `-help`
and `-devel` packages, or any other "optional" pieces.

And since this is all informal, it's pretty inconsistent. If something has
optional CLI tools, how do you find them? Is it under `-cli`, or `-console`,
or `-tools`, or `-utils`, or `-extras`? Is an optional GUI tool written in GTK3
found under `-gtk` or `-gtk3` or `-gui`?

We've also got various competing traditions for splitting up packages like
`git` or `vim` or `libreoffice` that have a bunch of optional parts with some
shared common code, but a typical "default" set of things that most people
want:

* LibreOffice: The `libreoffice` package itself is empty, but it `Requires`
  the standard suite set of apps: `-calc`, `-draw`, `-impress`, `-writer`, and
  `-base`, which _isn't_ the "base" set of apps or libraries - it's a database
  frontend (ha ha!). They all depend on `libreoffice-core`, which has all the
  core libraries and tools and such.
* Git: The `git` package only contains a few commonly-used utilities - `git
  submodule`, `git am`, `git instaweb`, and a couple others. `git-core` is the
  "minimal" core (which has everything else); other tools are in other `git-`
  packages.
* vim: There is no default `vim` package, but you can pick `vim-minimal` or
  `vim-enhanced`, which both require `vim-common` and `vim-filesystem`.

It's all kind of a mess, and you kind of just have to guess which pieces might
be useful or relevant to you - would you be able to guess from the package
names alone that `gitk` and `gitg` are git GUIs, and while `gitweb` _is_ a web
frontend, there's already a web frontend (`git instaweb`) in the `git` package
itself?

## So what have we learned?

I think looking at all the weird stuff we're doing with RPM names shows us a
few things that our ideal software packaging ecosystem should handle:

1. External packaging/module systems should probably have their own namespaces
2. The build environment, build options, and build target are relevant pieces
   of metadata about a build, and should be part of its identity
3. Packages should be able to declare different kinds of relationships between
   each other - formal and informal
4. There are a lot of relationships other than "required to install/run" that
   people might want to know about
5. It's enormously helpful to be able to provide metadata at the level of
   individual files
7. It's also helpful if you can apply multiple tags to the same thing
6. Using common type/purpose tags is a great idea, but users should definitely
   be able to define new tags when needed

You can probably see a theme here: more flexible metadata, and more of it!
But how do we do that without overloading or breaking the stuff we already
have? Well, to answer that question, I think we need to take a closer look at
the metadata RPM and DNF already use, and how exactly it's stored and used.

So, coming soon: join me as I dig deep into the horrors of the RPM header
format itself! And bring a stiff drink, 'cuz we're both gonna need it.

* * * * * *

[^1]: The table data is only for the `x86_64` 'Everything' repo. The counts
      are slightly different if you include updates, but you get the point.

[^2]: Except FC3, mostly because we renamed all the `xorg-x11-XXX-fonts`
      packages to `fonts-xorg-XXX`.

[^3]: Technically it only cares about package `Provides` - see David's
      excellent [RPM Dependencies] post if you want to know more.

[^4]: The "per-specfile" count is: "how many _source packages_ generate a
      subpackage with this word in it?" Two reasons for this: first, it cuts
      down on noise from packages like `texlive` or `pmda` that generate
      hundreds (or thousands!) of subpackages. More importantly, it's a better
      proxy for the real question, which is: what are the _users_ doing? What
      words do _packagers_ use most commonly when describing the stuff that
      gets built?

[^5]: `python -c 'import this'`, also known as [PEP20]

[^6]: Here's a link to [texlive's RPM sources] if you're curious.
      Fun fact: each changelog entry is repeated across all subpackages, which
      means that about 160MB of the 2.5GB(!) of RPMs produced by each new texlive
      build is just 5,931 copies of the new changelog. That's.. good, right?

[^7]: Again, while technically RPM lets you do `Requires: <FILENAME>`, that
      just resolves to "whichever package(s) provide `<FILENAME>`".
      You'll still get the whole package installed, even if you literally only
      require that one file.

[^8]: Okay, it also has `BuildRequires:`, because `rpmbuild` has to care about
      _building_ packages so that `rpm` can install them. But that's it!

[^9]: There are currently 1,348 packages in F27 that contain exactly one file.
      Fun fact: the package payload is smaller than the RPM headers for about
      2/3 of those (838/1348).

[Jakarta]: http://jakarta.apache.org/
[Apache Commons]: http://commons.apache.org/
[CPAN]: https://www.cpan.org/
[PEAR]: https://pear.php.net/
[golang]: https://golang.org/cmd/go/#hdr-Remote_import_paths
[gnome-shell]: https://en.wikipedia.org/wiki/GNOME_Shell
[Gnome Shell Extensions]: https://extensions.gnome.org/
[merged Core and Extras]: https://www.redhat.com/archives/fedora-devel-list/2007-January/msg00091.html
[the intro]: {% post_url 2018-03-15-Unpacking-RPM-intro %}
[little script]: https://github.com/wgwoods/rpmtoys/blob/master/dnf-count-rpm-words.py
[rpm-name-word-counts.csv]: /assets/csv/rpm-name-word-counts.csv
[PEP20]: https://www.python.org/dev/peps/pep-0020/
[texlive's RPM sources]: https://src.fedoraproject.org/cgit/rpms/texlive.git/tree/?h=f27
[RPM dependencies]: {% post_url 2018-03-29-RPM-Dependencies %}
