---

layout: post
title: "Unpacking RPM: package names"
author: wwoods

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

## What are RPM names actually trying to do?

To try to figure out what people are trying to do with RPM names, I took a
look at the most common "words" in package names.

If you're on a Fedora system and you'd like to play along, here's a one-liner
that'll generate a list of words, sorted by number of occurrences:

```shell
dnf repoquery --qf '%{NAME}' --repo="fedora" --repo="updates" \
    | tr '-' '\n' | sort | uniq -c | sort -n | tac | less
```

I wrote a [little script] to do slightly fancier analysis of the words in RPM
names - keeping word pairs like "`apache-commons`" as a single word, counting
use as prefix or suffix, and categorizing each "word" based on what kind of
thing they indicate about the package. Here's the results from that:

{% capture csvdata %}
word,pkgs,prefix,suffix,meaning
devel,4407,0,4398,file-type
perl,2953,2898,58,package prefix
python3,1856,1819,39,build-variant
doc,1703,0,1700,file-type
python2,1536,1520,12,build-variant
javadoc,1241,0,1241,file-type
nodejs,1129,1129,0,package prefix
python,1069,934,118,programming language
rubygem,635,635,0,package prefix
php,620,611,10,programming language
golang,465,464,0,package prefix
github,444,0,1,
libs,436,0,435,file-type
ghc,430,430,1,package prefix
unit-test,413,0,188,file-purpose
common,327,1,297,core/extras
fonts,323,2,318,file-type
tools,303,0,296,file-purpose
plugin,290,0,227,extends/enhances
static,264,0,262,build-variant
mingw32,229,229,0,build-variant
mingw64,217,217,0,build-variant
utils,196,0,193,file-purpose
Test,193,0,10,
data,164,0,144,file-type
gnome,164,107,53,environment
java,155,29,101,programming language
client,153,0,137,file-purpose
maven,148,91,2,framework
R,147,144,3,programming language
server,144,0,129,file-purpose
docs,141,0,138,file-type
core,139,0,126,core/extras
api,138,1,120,file-purpose
go,137,5,6,programming language
tests,136,0,134,file-purpose
rust,132,132,0,programming language
plugins,128,0,78,extends/enhances
hunspell,126,125,1,project name
kf5,126,125,1,framework
examples,125,0,124,file-purpose
qt5,117,43,50,framework
horde,112,0,2,project name
erlang,111,110,1,programming language
ocaml,105,101,4,programming language
Net,105,0,0,
parent,102,0,97,file-type
theme,101,0,75,file-type
Horde,100,0,0,
drupal7,99,99,0,project name
Plugin,95,0,3,
gtk,88,15,60,framework
Class,88,0,10,
Text,84,0,1,
File,83,0,5,
zendframework,80,0,1,framework
gui,79,0,75,file-purpose
jboss,79,74,2,project name
qt,76,10,61,framework
test,76,1,47,file-purpose
eclipse,76,74,1,project name
zend,76,0,0,framework
cli,75,1,62,file-purpose
Module,75,0,2,
MooseX,75,0,0,
django,72,0,3,framework
XML,71,0,6,data format
sugar,71,69,2,environment
is,70,1,14,
kde,69,22,33,environment
Data,68,0,4,
HTML,68,0,6,data format
base,67,0,59,core/extras
compat,67,20,42,build-variant
ruby,65,31,25,programming language
config,63,0,41,file-type
php-pear,62,61,0,package prefix
mysql,61,6,53,framework
Simple,61,1,47,
globus,60,58,2,project name
js,60,43,15,programming language
lua,58,39,16,programming language
CGI,58,0,2,
http,56,2,19,protocol
hyphen,56,55,1,
json,55,7,24,data format
Crypt,55,0,1,
Devel,54,0,1,
extras,53,0,39,core/extras
openmpi,52,1,51,framework
Catalyst,52,0,2,
emacs,51,39,12,project name
gap-pkg,51,51,0,package prefix
lib,50,0,42,file-type
mpich,50,1,49,framework
xfce4,50,49,0,environment
fedora,49,33,12,vendor
trytond,49,49,0,project name
HTTP,48,0,7,
php-pecl,48,48,0,package prefix
aspell,46,44,2,project name
util,44,0,25,file-purpose
filesystem,43,0,41,file-type
web,43,1,33,file-purpose
xorg-x11,41,41,0,project name
git,40,22,11,framework
stream,40,1,28,concept
manager,40,0,26,file-purpose
apache-commons,39,39,0,project name
mate,38,25,13,environment
cache,38,0,28,file-purpose
octave,37,33,3,programming language
tcl,37,23,14,programming language
xml,37,7,22,data format
glib,36,2,33,framework
ldap,36,0,31,protocol
file,36,2,18,concept
demo,35,0,35,file-purpose
el,35,0,32,data format
postgresql,35,8,27,framework
system,34,16,5,concept
console,34,3,21,file-purpose
trac,33,31,1,framework
gnome-shell,33,31,1,project name
jenkins,33,30,2,project name
vim,33,22,10,project name
mono,33,13,2,programming language
google,33,13,1,vendor
Tiny,32,0,32,
extra,32,1,25,core/extras
XS,31,0,29,
gtk3,31,1,23,framework
lv2,30,29,1,framework
backgrounds,30,0,29,file-type
selinux,30,1,29,framework
sqlite,30,2,27,framework
gtk2,30,2,21,framework
ibus,29,28,0,framework
agent,29,0,22,file-purpose
c,29,2,20,programming language
glassfish,28,27,0,project name
parser,28,0,26,file-purpose
it,28,0,25,translation
Parser,28,0,22,
dbus,28,9,17,framework
mythes,27,27,0,file-type
manual,27,0,26,file-purpose
qt4,27,3,24,framework
runtime,27,0,24,file-purpose
log,26,0,19,file-purpose
plexus,25,23,2,project name
gimp,25,21,4,project name
plasma,25,20,2,framework
es,25,0,22,translation
driver,25,0,19,extends/enhances
gfs,24,24,0,
platform,24,18,5,
fr,24,0,24,translation
sharp,24,0,22,programming language
de,24,0,22,translation
extensions,24,0,21,extends/enhances
xstatic,23,23,0,
xfce,23,2,19,environment
generator,23,0,18,
info,23,0,17,file-type
nuvola,22,22,0,
daemon,22,0,21,file-purpose
modules,22,0,20,extends/enhances
debug,22,0,18,build-variant
coin-or,21,21,0,project name
felix,21,21,0,project name
glite,21,21,0,project name
pidgin,21,19,2,
jackson,21,18,1,project name
fuse,21,11,9,
ru,21,0,20,translation
cs,21,0,19,translation
support,21,0,19,
c++,21,1,17,programming language
sblim,20,20,0,project name
vdr,20,20,0,
gstreamer,20,9,7,
pgsql,20,0,20,framework
ng,20,0,19,
i18n,20,0,18,translation
fcitx,19,17,2,
pom,19,0,19,
builder,19,0,18,
lxqt,18,18,0,environment
apache,18,11,6,
demos,18,0,17,
geronimo,17,17,0,project name
ladspa,15,15,0,
springframework,15,15,0,project name
telepathy,15,13,2,
nagios,15,11,3,project name
adobe,13,13,0,
switchboard,13,13,0,
jetty,13,13,0,project name
lohit,13,13,0,
NetworkManager,13,12,0,project name
scim,13,12,1,
sil,12,12,0,
cinnamon,12,11,1,
vagrant,12,10,2,
man-pages,12,10,0,project name
gdouros,11,11,0,
ktp,11,11,0,
purple,11,11,0,
libopensync,11,11,0,
wingpanel,10,10,0,
aries,10,10,0,
oflb,10,10,0,
{% endcapture %}
{% include csvtable.html data=csvdata height="480px"
   caption="Top 100 most common words/prefixes/suffixes in RPM names (F27, x86_64)" %}
(full data set: [rpm-name-word-counts.csv])

Looking over this list, I'd say there's 5 main things we're trying to do with
all our RPM name-mangling:

### 1. Language/project/vendor namespace prefixes

As a wise man once observed, "Namespaces are one honking great idea --
let's do more of those!"[^4] Sure enough, the 10 most common prefixes are
language or project names. But RPM doesn't actually _have_ separate namespaces
for any of those things, so in reality every package gets crammed into one big
heap and the user has to figure out the rest.

So even if you've never used `texlive` or `nodejs` you're still downloading
and searching all the metadata for every package in those ecosystems every
time you run `dnf`. Yuck.

Also.. `python2` and `python3` are pulling double duty. They're _kinda_
language prefixes, but they're _also_ variant-build markers!

Interesting note: when a language or project name is used in a _suffix_, it
has a slightly different meaning - usually "bindings for LANG" or "built
with/for PROJ".

### 2. Parallel-installable variant builds

There's a lot of times that we want multiple variant builds of a project to be
available and/or parallel-installable, but we can't do that without modifying
the RPM name.

Most commonly, we want to build the same source more than once, using a
different toolchain or build options. Since RPM doesn't know anything about
the build environment or build options we have to change the name to make RPM
consider them different builds - and that's where we get `-debug`, `-static`,
`python2-`/`python3-`, `-qt4`/`-qt5`, `mingw64-`/`mingw32-`, and so on.

Other times we're building two _versions_ of the same package, because some
things require the older version and some require the newer one. RPM
technically allows this (as long as the package _contents_ don't overlap) but
the default behavior (as enforced by yum and dnf) is to _replace_ older
versions of packages with newer ones. So we add `-compat` or `compat-` to the
older version to change its name, thus making RPM consider it a different
package.

### 3. Informal "extends/enhances"

Sure, we have soft dependencies now, but we still use a lot of unwritten
conventions that _imply_ relationships between projects. One interesting
example is the use of `plugin`/`plugins` - there's different "phrasings" that
can have slightly different meanings:

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
encode it into the RPM name in a way that's _not machine-readable_.

### 4. File type/purpose tags

We sure do love labeling things.

**TODO IMPROVE**

It's pretty good that we label docs as such, but it's kind of a shame that
we have like 7 different tags for that: `doc`, `docs`, `javadoc`, `help`...

Also, it's a shame we can't apply multiple "tags" to files. If you've got some
example code in your docs, does that go in `examples` or `docs`?

Also things like `tools`, `utils`, `unit-test`, etc.

Again: it's a good idea, but inconsistent: if you've got an optional CLI, is
that `-cli` or `-console`? Is an optional GUI tool written in GTK3 found under
`-gtk` or `-gtk3` or `-gui`? Or `-tools`? Or maybe just.. `-extra`!

## So what have we learned?

**TODO DOUBLECHECK / IMPROVE**

1. Users want to be able to define their own file-level metadata tags
1. We want soft/optional dependencies
1. We should have namespaces for other packaging systems
1. The build environment/target is a significant piece of data about a build
1. `texlive` is _fucked up_

* * * * * *

[^1]: The table data is only for the `x86_64` 'Everything' repo. The counts
      are slightly different if you include updates, but you get the point.

[^2]: Except FC3, mostly because we renamed all the `xorg-x11-XXX-fonts`
      packages to `fonts-xorg-XXX`.

[^3]: Technically it only cares about package `Provides` but talking about how
      `Provides`/`Requires`/etc. work is gonna be a much, much longer post.

[^4]: `python -c 'import this'`, also known as [PEP20]

[Jakarta]: http://jakarta.apache.org/
[Apache Commons]: http://commons.apache.org/
[CPAN]: https://www.cpan.org/
[PEAR]: https://pear.php.net/
[golang]: https://golang.org/cmd/go/#hdr-Remote_import_paths
[gnome-shell]: https://en.wikipedia.org/wiki/GNOME_Shell
[Gnome Shell Extensions]: https://extensions.gnome.org/
[merged Core and Extras]: https://www.redhat.com/archives/fedora-devel-list/2007-January/msg00091.html
[the intro]: /Unpacking-RPM-intro
[little script]: https://github.com/wgwoods/rpmtoys/blob/master/dnf-count-rpm-words.py
[rpm-name-word-counts.csv]: /assets/csv/rpm-name-word-counts.csv
[PEP20]: https://www.python.org/dev/peps/pep-0020/
