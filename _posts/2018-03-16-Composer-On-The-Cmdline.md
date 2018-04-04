---
layout: post
title: Composer on the Cmdline
author: bcl
tags: lorax-composer
---

lorax-composer now has a command line tool, it is called `composer-cli`, and it
can be installed from the [lorax-composer
repo](https://copr.fedorainfracloud.org/coprs/g/weldr/lorax-composer/packages/)
by running `yum install composer-cli`. It uses the lorax-composer socket file
to communicate with the API server so it must be run on the same system as
lorax-composer, and by a user who has permission to access the socket. eg. root
or a member of the weldr group.

Start out by [setting up a VM with lorax-composer installed]({% post_url
2018-02-15-Experimenting-with-lorax-composer %}) (the playbook has been updated
to include composer-cli), and log into the system. You can either use root, or
setup a new user who is a member of the weldr group.  eg. `useradd -m -G weldr
kaylee`

## Edit an existing recipe

When lorax-composer is installed it includes several example recipes. Let's
edit the http-server recipe and switch it from using MySQL to PostgreSQL as its
database. While we're at it we'll add the vim-enhanced package so that we don't
have to remember to type `vi` when trying to edit files:

- List the recipes to make sure the API server is available. `composer-cli recipes list`
- Download the `http-server` recipe. `composer-cli recipes save http-server`
- Edit the recipe. `vi http-server.toml`

The recipe file is formatted using [Tom's Obvious, Minimal
Language](https://github.com/toml-lang/toml), so editing it should be pretty
simple:

- Change the version number to `0.1.0` since this not a trivial change.
- Update the description, replacing MySQL with PostgreSQL.
- Change the `php-mysql` module entry to `php-pgsql`
- Add a new `[[module]]` entry and add version 5.1 of `phpPgAdmin`
- Add another entry with version `7.4.*` of vim-enhanced

Note that as of version 19.7.11 the recipe's version information is not used
for depsolving. It uses the most recent package that is available from the
repos, and the repos used are the ones that are enabled on the host system.
In the future it will be possible to add, or completely replace, the repo
list used for a compose.

Now you can push the new recipe back to the API server with `composer-cli
recipes push http-server.toml`. This will add a new git commit for the updated
recipe, which you can see by running `composer-cli recipes changes
http-server`. You can also view the differences between the two commits by
using the diff command: `composer-cli recipes diff http-server
4a6b744eb723d2648099291f8ed34dd2ccddaa49 NEWEST`

![composer-cli Screenshot]({{ "/assets/composer-cli-1.jpg" | absolute_url }})

## Compose a partitioned-disk image

You can make sure the recipe's dependencies are available by running
`composer-cli recipes depsolve http-server`, it will return a list of the
package NEVRAs that will be installed.

Start the compose with `composer-cli compose start http-server
partitioned-disk`, which returns the UUID of the compose. This will be used to
retrieve the logs and results when it is finished running.

`composer-cli compose status` will display the status of all of the composes on
the system. Your new one will be listed as `WAITING` until it is ready to
build, and then it switches to `RUNNING`. When it is done it will be `FINISHED` or
`FAILED`.  Anaconda's log is available with `composer-cli compose log UUID`.
Let it run until the status changes to `FINISHED`, which should take around 15
minutes on a 2 core VM with 2048MB of RAM.

When the compose is done the results are available in several ways:

- `composer-cli compose results UUID` will download the metadata and the image.
- `composer-cli compose metadata UUID` will download the build metadata. The frozen recipe, kickstart, etc.
- `composer-cli compose logs UUID` only downloads the logs from the compose.
- `composer-cli compose image UUID` will download just the image.

Download the disk image with `composer-cli compose image UUID`, it will be
saved as UUID-disk.img. You can then copy it to the host and use your favorite
virtualisation system to boot the image. eg. with virt-manager select 'Import existing disk image' and
follow the prompts.

composer-cli also supports dumping the raw JSON to the terminal, just pass it
`--json`. If there is an error the command will print out a useful help
message, and return a 1 instead of a 0 so that it can be used to build
scripts for automating image creation.

With the current version (19.7.11) of lorax-composer all of the above steps
will also work for building tar and live-iso images.
