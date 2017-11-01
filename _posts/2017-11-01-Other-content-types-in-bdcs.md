---
layout: post
title: Other content types in BDCS
author: dshea
---

In an effort to move beyond only storing RPM content in the bdcs, I've been trying to extend import and export to handle JavaScript packages from npm. Npm seemed like a good first choice since there's usually nothing to build, and since the welder-web frontend makes use of npm packages it would be a first step towards a self-hosting welder system.

The main difference between RPM imports and everything else is that RPM describes an exact mapping from data to filesystem, while source-based registries, such as npm, pip, hackage, or gem, do not. Even for languages that are not compiled, there needs to be a "build" step to translate the source archive paths to their final form.

The import/export process we currently have for RPM is, roughly:

* Unpack the RPM into the content-store
* Map the RPM files to a `groups` record in the mddb
* Save the dependencies in `requirements` in the mddb
* ...
* Select a `groups` based on a recipe
* Depsolve the `requirements` to pull in other necessary groups
* Write all of the groups' files to the new filesystem.

Modifying this process for source-based archives looks something like:

* Import the source archive into the content-store
* Map the source files to a `sources` record in the mddb
* Store the build dependencies for the source
* ...
* Depsolve a recipe request into a set of packages and requirements
* Look for builds satisfying the requirements
* Build and cache any missing requirements
* Write the builds' files to the new filesystem.

So far, the code to import an npm archive exists, the code to export it does not, and the code to build it is kind of weird and iffy. The original plan, since "building" an npm package just means making some symlinks, was to find all possible versions satisfying a given dependency list and create the builds at import time. The javascript world's combination of long dependency lists, loose version requirements, and frequent releases turned this idea into a bad combinatorics problem. Even the simple process of creating symlinks on import becomes impossible as the list of possible combinations grows into the billions. Besides the present problem, using an on-demand-then-cache build system will fit better with more intense build process, such as compiling a Haskell package.

The npm import/export, once complete, will give us an idea of how welder can combine RPM data with data from other package registries, as well as how modularize registry-specific logic within bdcs. Stay tuned to this space for more, or join us on [IRC](Find-us-on-IRC) or [github](http://github.com/weldr/).
