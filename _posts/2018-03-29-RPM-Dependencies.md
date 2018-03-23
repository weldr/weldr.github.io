---
layout: post
title: What is a Dependency, Anyway
author: dshea
math: true
---

A RPM package is not just a pile of files. It's also a pile of metadata to help
with the management of those files. RPM allows the user to track files, verify
them, and keep everything internally consistent through dependencies. So how do
dependencies work?

## The Basics: NEVRA, Provides

### ¿Cómo se llama?

RPM has two ways of describing what a package *is*: the NEVRA, and the Provides tags.

NEVRA refers to five pieces of information: Name, Epoch, Version, Release, Architecture.
The Name, Epoch, Version, and Release are provided by the package maintainer, and the
Architecture is determined by the build.

"Name" is the name of the package. "Architecture" is the processor type that the package
is built for, or "noarch" if it doesn't matter. So far so good. The middle three components (EVR)
make up the package's version: "Version" is intended to match the upstream version, "Release"
is information about the particular build and is usually just a number that increases for
each build of a version, and "Epoch" is a number that acts like a super version. The Epoch
overrides all of the other version checks, and it can be used to force a package to be
considered an "upgrade" over another package, even if the Version and Release fields are lower.

EVRs are orderable. Given two EVR values, you can say whether they are equal or whether one
of them is greater than the other one. Roughly, the process of comparing versions is:

  * If the Epochs are not equal, the EVR with the greater Epoch is greater. Otherwise,
  * if the Versions are not equal, the EVR with the greater Version is greater. Otherwise,
  * if the Releases are not equal, the EVR with the greater Release is greater. Otherwise,
  * the EVRs are equal.

NEVRAs are generally written as NAME-[EPOCH:]VERSION-RELEASE.ARCH; e.g., tar-2:1.29-7.fc27.x86_64. If the
epoch is not specified, it's treated as 0.

That's the basic idea of what a package represents, and how it can be compared to other packages with the same name.

### Tell me more about yourself

RPM metadata includes a list of what a package "Provides". A Provides name is just a free-form string, like "Provides: webserver".
Some of this data is hand-maintained, and some of it is added automatically by rpm. For example, when building a
package rpmbuild will automatically generate Provides data for shared objects, such as "libz.so.1()(64bit)". rpmbuild
also copies the package NEVRA into the Provides data, for example "zlib(x86-32) = 1.2.11-4.fc27". That will become important
in a minute.

Provides strings can optionally include a version, like in "zlib(x86-32) = 1.2.11-4.fc27". Everything to the
left of the equal sign (minus whitespace) is the Provides name, and everything to the right of the
equal sign (minus whitespace) is the Provides EVR. Architecture is not considered a separate piece here.
In this example, it's included in the name.

The Release part of a Provides EVR is optional, and a missing release is treated as a wildcard. For example,
"zlib = 1.2.11" will match any name=zlib, epoch=0, version=1.2.11.

The equal sign can actually be any one of ">", ">=", "=", "<=", "<". Specifying a range is more common with the other
types of metadata, but it can happen with Provides as well, though it probably shouldn't. In Fedora there are currently
30 packages with a greater-than or a less-than operator in their Provides metadata.

Now we know the ways a package can describe itself. How is this information used?

## Simple dependencies: PRCO

Every time a set of packages is added to a system or removed from a system, RPM checks to ensure that the
dependency data remains consistent. The simplest way to express this is via the four classic dependency
types: Provides, Requires, Conflicts, Obsoletes. Like Provides, each of these headers consists of a name,
an optional comparison operator and a EVR.

Requires is the inverse of Provides. For a Requires to be satisfied, there must be a Provides that 1) matches
the name exactly, and 2) overlaps the EVR range.

```
# These two match, for example
Requires: foo >= 1.0
Provides: foo =  1.1
```

Requires can also match file names. A requires specification such as:

```
Requires: /bin/sh
```

will match either a package that Provides /bin/sh, or a package that contains the path /bin/sh as part of its payload.

Conflicts essentially means "Not Requires". For a Conflicts to be satisfied, there must *not* be a Provides
that would satisfy the name and EVR.

Obsoletes is a little different. The name part of the expression string used by Obsoletes matches the name from a NEVRA, not a Provides.
For an Obsoletes to be satisfied, there must not be a package with the given name and a matching EVR.

Obsoletes is mostly useful when renaming a package. For example, given a package with the following data:

```
Name: old-and-busted
Version: 1.0
Release: 1
```

If you installed old-and-busted, and then did an upgrade using a package with the following data:

```
Name: new-hotness
Version: 2.0
Release: 1
Obsoletes: old-and-busted < 2.0
```

RPM knows that new-hotness obsoletes old-and-busted, so it can remove old-and-busted and keep the metadata
consistent.

And that's it! Your classic, everyday dependencies are just taking all of the RPM data for all packages to be installed,
and validating them in three different ways.

$$
\begin{align*}
    & \forall{r \in Requirements}(\exists{p \in (Provides \cup Filenames)}: p \models r) \\
    & \forall{c \in Conflicts}(\nexists{p \in (Provides \cup Filenames)}: p \models c) \\
    & \forall{o \in Obsoletes}(\nexists{n \in NEVRAs}: n \models o)
\end{align*}
$$

## Dependency verification vs. dependency solving

By itself, RPM only verifies dependencies. This means that if you want to install a package, you have to
provide RPM with all of the requirements for the package. This can get unwieldy in a hurry. For example,
to install bash, the minimum set of packages in Fedora 27 is:

* fedora-gpg-keys
* fedora-repos
* fedora-release
* setup
* filesystem
* basesystem
* tzdata
* ncurses-base
* glibc-all-langpacks
* glibc-common
* glibc
* ncurses-libs
* bash
* libsepol
* pcre2
* libselinux

No one wants to figure all of that out by hand, which is where dependency solvers come in. Tools like
up2date, yum, and dnf are able to search a package repository for necessary requirements, and then hand a
complete set of packages to RPM.

A dependency solver has two inputs: the set of packages to install, and a set of all known packages. The
output is a complete set of packages that satisfy all of the requirements of the packages to install. 

In the PRCO world, package requirements can be expressed as a boolean formula: a package installation needs every
requirement of that package to evaluate to "True" and every conflict or obsolete for that package to evaluate to "False".

For each requirement, conflict, and obsolete, create a disjunction over all packages that can satisfy the clause.
The formula is then the conjunction of all the requirement formulas, the negation of all of the conflict formulas,
and the negation of all of the obsolete formulas.

$$
\begin{align*}
    Pkgs_{A_r} & = \bigwedge\limits_{r \in Requirements_A} (\bigvee \{ pkg \in Repository: (\exists p \in Provides_{pkg}: p \models r )\})\\
    Pkgs_{A_c} & = \bigwedge\limits_{c \in Conflicts_A}    (\bigvee \{ pkg \in Repository: (\exists p \in Provides_{pkg}: p \models c \})\\
    Pkgs_{A_o} & = \bigwedge\limits_{o \in Obsoletes_A}    (\bigvee \{ pkg \in Repository: NEVRA_{pkg} \models o \})\\
        Pkgs_A & = Pkgs_{A_r} \land \neg{Pkgs_{A_c}} \land \neg{Pkgs_{A_o}}
\end{align*}
$$

Then recurse over the requirements to gather their dependencies. The final result of packages
to install is a boolean satisfiability problem.

## Weak dependencies: Recommends, Suggests, Supplements, Enhances

RPM 4.13 added four new metadata tags: Recommends, Suggests, Supplements, and Enhances. Like the PRCO tags,
they consist of a name and an optional version.

"Recommends" is a "weak" requires, and "Supplements" is a reverse weak requires, meaning that "packageA Supplements packageB"
is the same as "(a package providing packageB) Recommends packageA".

"Suggests" is a "very weak" requires, and "Enhances" is the reverse version of Suggests.

What does this all mean for dependency validation? Absolutely nothing. A weak requirement is allowed to be missing, so the
result of the validation is the same whether the weak dependency is satisfied or not. Weak requirements are instead intended
to be used by one of [the layers on top of RPM](/Unpacking-RPM-intro/), such as dnf.

### Kinda-requires: Recommends and Supplements

The idea behind Recommends is that it describes packages that *should* be a part of the transaction,
but don't *need* to be part of the transaction.  If satisfying a Recommends is not possible, it can be ignored
and the transaction will still be valid.

Supplements describes the same sort of relationship, but in the other direction. However, Recommends and Supplements
describe different data. Like "Requires" and "Conflicts", "Recommends" and "Supplements" match "Provides", but they
match in different directions. For PkgA that "Recommends: ProviderB", the relationship is satisfied by any package
that "Provides" ProviderB.

$$
Pkgs_{A_{recommends}} = \bigcup\limits_{rec \in Recommends_A} \{ pkg \in Repository: (\exists p \in Provides_{pkg}: p \models rec )\}
$$

For the case of PkgB "Supplements: ProviderA", a package being installed has a Recommends relationship with PkgB if any
of the to-be-installed package providers satisfy ProviderA.

$$
Pkgs_{A_{supplementedBy}} = \bigcup\limits_{p \in Provides_A} \{ pkg \in Repository: (\exists sup \in Supplements_{pkg}: p \models sup )\}
$$

For each of these relationships, the transaction is *more* valid if it contains the recommended/supplemented packages, but it
is not *invalid* if it is missing them. Solving dependencies with weak dependencies is no longer a satisfiability problem.

It's worth repeating that, from a boolean validity point of view, it is completely correct to ignore weak dependencies.

### Sorta-requires: Suggests and Enhances

Suggests and Enhances are intended to be hints. For cases where a requirement (or recommendation) could be satisfied by
more than one package, if a Suggests expression would break the tie, the depsolver is expected to use the Suggested package.

For example, if we have the following:

```
Name: cool-web-app
Requires: webserver
Suggests: nginx
```

```
Name: httpd
Provides: webserver
```

```
Name: nginx
Provides: webserver
```

The requirements for "cool-web-app" could be satisfied by either httpd or nginx, but it has a Suggests header to indicate that,
if possible, the depsolver should choose nginx.

Functionally, Suggests and Enhances are the same are Recommends and Supplements: both pairs of relationships describe a requirement
that *should* be satisfied, if possible. The difference is that while Recommends and Supplements attempt to satisfy the requirement
from the set of all available packages, Suggests and Enhances try to satify the requirement only from the packages that are already
possible solutions to a transation.

$$
\begin{align*}
    Pkgs_{A_{suggests}}   & = \bigcup\limits_{sug \in Suggests_A} \{ pkg \in Transaction: (\exists p \in Provides_{pkg}: p \models sug)\}\\
    Pkgs_{A_{enhancedBy}} & = \bigcup\limits_{p \in Provides_A} \{ pkg \in Transaction: (\exists enh \in Enhances_{pkg}: p \models enh )\}
\end{align*}
$$

This means that the packages involved in Suggests/Enhances relationships cannot be determined until the rest of the package set
has been calculated.

## Boolean dependencies

RPM 4.13 added the idea of boolean dependency strings. In addition to the simple "NAME [OPERATOR VERSION]" values, boolean
expressions, enclosed in parenthesis, can be used. The following expressions are allowed:

* (A and B)
* (A or B)
* (A if B [else C])
* (A unless B [else C])
* (A with B)
* (A without B)

"and" and "or" are pretty self-explanatory. "A if B [else C]" means $$B \implies A [\land (\neg{B} \implies C)]$$, and
"A unless B [else C]" means $$\neg{B} \implies A [\land (B \implies C)]$$.

For "with", the expression is satisfied by any package that satisfies both the left and
right operands. For "without", the expression is satisfied by any package that satisfies the left operand and does not satisfy
the right operand. "with" and "without" change the space that package requirements operate over. Instead of evaluating a requirement
across all possible packages, "with" and "without" create an expression that must be satisfied by a single package, and then use
that result in the global satisfiability problem.

Boolean expressions can be used in Requires, Recommends, Suggests, Supplements, Enhances, and Conflicts headers. In most cases,
the left and right operands can either be a "NAME [OPERATOR VERSION]" string, or another expression. There are lot of cases that
RPM will reject.

### Let's second guess what "if" means

RPM rejects all of the following:

1. Requires: ((A if B) or C)
2. Conflicts: ((A unless B) and C)
3. Requires: (A unless B)
4. Conflicts: (A if B)
5. Enhances: (A if B)

Let's try to unpack why.

The first and second expressions are rejected because they're confusing. The first formula, which
we could rewrite as $$((B \implies A) \lor C) \Leftrightarrow (\neg{B} \lor A \lor C)$$,
could be satisfied by any of the following assignments:

* A=True, B=True, C=True
* A=True, B=True, C=False
* A=True, B=False, C=True
* A=True, B=False, C=False
* A=False, B=True, C=True
* A=False, B=False, C=True
* A=False, B=False, C=False

The only combination rejected by the formula would be A=False, B=True, C=False, and RPM chose to forbid
the formula on the assumption that this information was not what was trying to be expressed.

The second case is less clear. When used without an "else" clause, "A unless B" is equivalent to "A or B",
and "Conflicts: ((A or B) and C)" is considered perfectly valid. If we were to add an else,
"((A unless B else D) and C)", we end up with $$(A \lor B) \land (D \lor \neg{B}) \land C$$, which
has four solutions. It could also be expressed as two separate Conflicts clauses:

```
Conflicts: (A unless B else D)
Conflicts: C
```

I really have no idea why RPM rejects combinations of "unless" and "and". Maybe it's an attempt for symmetry
with the "if/else" case.

The third formula, $$\neg{B} \implies A$$, is similar to the second. Without an "else", it can be expressed
as "(B or A)", and with an "else" it needs to be expressed as a combination of "Requires" and "Conflicts"
for reasons that are not particularly clear.

The fourth formula is the inverse of the third: Conflicts can't use "if". $$\neg{(B \implies A)} \Leftrightarrow (B \land \neg{A})$$
is equivalent to "Requires: (B); Conflicts: (A)", and RPM mandates that they be separated.

In the case of the fifth formula, $$(B \implies A) \Leftrightarrow (\neg{B} \lor A)$$, the formula
is rejected when used with the reverse dependency types, Enhances and Supplements, since it matches
A=False, B=False. Allowing this would allow packages to create Recommends/Suggests relationships with all packages
that don't have either of those "Provides" values, which would be pretty wild.

### The trouble with "with"

The following are also rejected by RPM:

1. Requires: ((A and B) with C)
2. Requires: ((A if B) with C)

"with" expressions apply the operands to a single package. To evaluate a "with" expression
the dependency validator or solver needs to take each operand, determine a set
of packages that could possibly satisfy the operand, and then take the intersection of the two sets.
"without" is similar, except that it takes the difference of the two sets.

Rejecting the first formula tells us something about RPM's rich dependency parser, and it demonstrates
how "with" and "without" create the need to continually query the dependency data as the expression is parsed.
"with" and "without" expressions need sets of individual possible packages on each side of the operator,
and that's a lot easier to do with "or" than with "and". So while "((A and B) with C)" *could* be interpreted
as "(A with B with C)", instead RPM is evaluating the left hand side, possibly producing an expression
along the lines of $$(pkg_{A_1} \lor pkg_{A_2} \lor ...) \land (pkg_{B_1} \lor pkg_{B_2} \lor ...)$$,
and then it gets to the "with" and can't reduce that expression to a set. On the other hand, an
expression like "(A or B)" on the left hand side could be evaluated as something
like $$pkg_{A_1} \lor pkg_{A_2} \lor pkg_{B_1} \lor ...$$, which easily converts to $$\{ pkg_{A_1}, pkg_{A_2}, pkg_{B_1}, ... \}$$.

The left-hand side of the second formula reduces to $$\neg{B} \lor A$$, and while this is a simple disjunction,
it's another example of RPM's unwillingness to use negation except in specific contexts.

### Did I mention that these expressions are technically unparseable

Remember that the pieces of a boolean expression use the same syntax as the PRCO headers we know and love.
A boolean expression can match any name that is a valid name in a Provides.

Consider the following perfectly valid, if unfortunate, Provides line in a Fedora 27 package:

```
Provides: bundled(python3dist(ipaddress) = 1.0.17
```

The parenthesis don't match. In the pre-boolean days this didn't matter a whole lot, but now we
have a new expression syntax where parenthesis are important. Suppose you want to write a requirement
for either a bundled or unbundled version python3-ipaddress, and you want it be possibly satisfied
by the package with the typo. You could do something like:

```
Requires: (bundled(python3dist(ipaddress) or python3-ipaddress)
```

But if you did this, it's a parse error:

```
Requires: (python3-ipaddress or bundled(python3dist(ipaddress))
```

Things only get worse if you have more closed parenthesis than open parenthesis. It might be treated
as a parse-error, or it might be parsed as a particularly odd combination of boolean and non-boolean
dependencies, depending on exactly how things are arranged. Some strings are simply impossible
to include in a boolean expression. Boolean dependencies don't explicitly create new restrictions on
Provides strings, but they work a lot better if you pretend that they do.

## Conclusions

Recent additions to the semantics of RPM dependencies make them both more expressive and more difficult
to use. Weak dependencies allow the dependency solution to be modified in certain ways while making the
dependency solution a more difficult type of problem. Boolean dependencies allow the dependency formula
to be extended in obvious, clear ways, but at the same time they restrict the formula in less clear ways,
redefine the sets of data that the formula uses, and create a language that is not possible to parse
entirely correctly.

Dependencies of some sort are necessary in order to build relationships between packages, but RPM dependencies
are complicated and difficult to perform calculations on, and they're only getting harder.
