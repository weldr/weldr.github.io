---
layout: post
title: Adding New Lorax Composer Output Types
author: bcl
tags: lorax-composer
---

When [lorax-composer version
19.7.10](https://copr.fedorainfracloud.org/coprs/g/weldr/lorax-composer/packages/)
is released it will support 3 output types.  `tar`, `live-iso`, and
`partitioned-disk`. Originally I was going to write about adding `live-iso`
support, but it ended up being [a bit more
complicated](https://www.github.com/rhinstaller/lorax/commit/7464736e9de8d6ef51d352b688cc2225536a7236)
than it needed to be, so after re-arranging the code to support all of the
livemedia-creator output types, we'll talk about adding partitioned disk
images.

lorax-composer is an API on top of livemedia-creator, which has a large number
of supported output types. In order to make these work with an API and clients
with minimal knowledge about the internals of building images and running
Anaconda we need a few extra things.

A kickstart file needs to be added to `./share/composer/`. The
name of the kickstart is what will be used by the `/compose/types` route, and the
`compose_type` field of the POST to start a compose.

It also needs to have
code added to the `pylorax.api.compose.compose_args()` function. The
`_MAP` entry in this function defines what lorax-composer will pass to
`pylorax.installer.novirt_install()` when it runs the compose.

When the compose is finished the output files need to be copied out of the
build directory (`/var/lib/lorax/composer/results/<UUID>/compose/`),
`pylorax.api.compose.move_compose_results()` handles this for each type.  You
should move them instead of copying to save space.

If the new output type does not have support in livemedia-creator it should be
added there first. This will make the output available to the widest number of
users.

## Example: Add partitioned disk support

Partitioned disk support is something that livemedia-creator already supports
via the `--make-disk` cmdline argument. To add this to lorax-composer it
needs 3 things:

* A `partitioned-disk.ks` file in `./share/composer/`
* A new entry in the `_MAP` in `pylorax.api.compose.compose_args()`
* Add a bit of code to `pylorax.api.compose.move_compose_results()` to move the disk image from
  the compose directory to the results directory.

The `partitioned-disk.ks` is pretty similar to the example minimal kickstart
in `./docs/rhel7-minimal.ks`. You should remove the `url` and `repo`
commands, they will be added by the compose process. Make sure the bootloader
packages are included in the `%packages` section at the end of the kickstart,
and you will want to leave off the `%end` so that the compose can append the
list of packages from the recipe.

The new `_MAP` entry should be a copy of one of the existing entries, but with `make_disk` set
to `True`. Make sure that none of the other `make_*` options are `True`. The `image_name` is
what the name of the final image will be.

`move_compose_results()` can be as simple as moving the output file into
the results directory, or it could do some post-processing on it. The end of
the function should always clean up the `./compose/` directory, removing any
unneeded extra files. This is especially true for the `live-iso` since it produces
the contents of the iso as well as the boot.iso itself.

You can see all of these changes in [this
commit](https:www.github.com/rhinstaller/lorax/commit/6aa7d9bd07dc2a2e635b524cfca087bf89eb521e),
[and this commit of the ks file](https:www.github.com/rhinstaller/lorax/commit/0303ab8ecb69e49ff65c88a53efcfdc74a81b6cb).
Feel free to add more output support and [file pull requests on
GitHub](https://www.github.com/rhinstaller/lorax/pulls).

