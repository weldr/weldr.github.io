---
layout: post
title: Add Files From Git Repositories
author: bcl
tags: lorax-composer
---

When you are building an image sometimes you need to add some configuration
files, extra tools, etc.  The temptation is to just copy them over from your
local system and move on, but that isn't the right answer.  Unless you document
where the files came from nobody looking at the image in 6 months will remember
which version of them was included, where they came from, or even who created
them.

The right way to do this is to take your files and package them into an rpm,
using the description to document their source, and the package version to keep
track of them as you add them to an extra repository.  You can then add this
repository to lorax-composer using the `composer-cli source` commands.

Or, you could let composer handle creating the rpm for you and just point it
to the git repository of files you want to include.

In version 31.0 of lorax-composer we have added a new feature to the blueprints
that does exactly that.  You add a section to the blueprint pointing to the git
repo and composer will make an rpm of it and install the files under the
destination path that you specify.  The rpm that is installed in the image
includes the exact details about where the files came from so there is no
question about their source.

You should be using lorax-composer-31.2 or later on a Fedora 31 host.  Make sure
that the lorax-composer.service is started - `systemctl start
lorax-composer.service`.  The first use of `composer-cli` may be delayed
until lorax-composer finishes downloading the current metadata
for the enabled repos.

Let's walk through an example scenario with nginx and some virtual hosts.

Nginx virtual hosts
-------------------

You can easily set up virtual hosts in nginx by adding configuration files to the
`/etc/nginx/conf.d/` directory.  In their simplest form they look like this:

    server {
            listen 80;
            server_name one-site.myhost.com;
            root /var/www/one-site.myhost.com/public_html;
            index index.php index.html;
    }

I have set up an [example git repository here](https://github.com/bcl/extra-files), it includes 3 vhosts
along with their html directories under `/var/www/`.

Starting nginx at boot time
---------------------------

One of the limitations of lorax-composer is that there is currently no way to
specify which services need to be started at boot time -- we're working on
this, take a look at [my customizations proposal
PR](https://github.com/weldr/lorax/pull/634) for an idea of where we're headed.
In order to start a service it either needs to be set up to start by the package
that installs it, or enabled by using something like Ansible after the system
boots.  The other alternative is to drop in a symlink to its systemd service
file as part of our extra files repository.

To do this you create a symlink under `/etc/systemd/system/multi-user.target.wants/`
that points to the service file.  This is relative to the top directory of the
git repository, NOT the / of your development system:

    mkdir -p etc/systemd/system/multi-user.target.wants
    cd etc/systemd/system/multi-user.target.wants
    ln -s /usr/lib/systemd/system/nginx.service .

Building an nginx qcow2 image with the extra files
--------------------------------------------------

We now have a git repository with all the files we want to add, as well as a symlink that
will cause nginx to start at boot time. We need to create a blueprint, from the command
line, that includes nginx and the git repository information.

Open up a text editor and create `nginx-extra-vhosts.toml` file and add this to it:

    name = "nginx-extra-vhosts"
    description = "An nginx server including some custom vhosts"
    version = "0.0.1"
    groups = []

    [[packages]]
    name = "nginx"
    version = "1.*"

    [[packages]]
    name = "nginx-all-modules"
    version = "1.*"

    [[customizations.user]]
    name = "root"
    key = "ssh-rsa ..... user@localhost.localdomain"

    [[repos.git]]
    rpmname = "vhosts"
    rpmversion = "1.0"
    rpmrelease = "1"
    summary = "vhosts for nginx server"
    repo = "https://github.com/bcl/extra-files"
    ref = "v1.0"
    destination = "/"

What this blueprint does is install a minimal system with nginx and all of its
modules. You should set up the root account's ssh key or password so that you
can login (see the [customizations.user documentation
here](http://weldr.io/lorax/lorax-composer.html#customizations-user).

It then points composer to our example repository, names the rpm `vhosts` with
a version of `1.0-1`. We are going to use a tag, v1.0, to select which commit
to install and the files at the root of the repository will be copied directly
into the / of the system.

You can also use a branch name for the ref, eg. `origin/vhosts-test`, or a commit
hash like `8f02209754ef796a37d15b897049f43b51e23b3d`.

On the composed image you will have an rpm named `vhosts-1.0-1` installed, with
the description pointing to the git repository and reference used to create the
rpm -- `rpm -qi vhosts`:

    Name        : vhosts
    Version     : 1.0
    Release     : 1
    Architecture: noarch
    Install Date: Fri 29 Mar 2019 07:51:34 PM EDT
    Group       : Applications/Productivity
    Size        : 1273
    License     : Unknown
    Signature   : (none)
    Source RPM  : vhosts-1.0-1.src.rpm
    Build Date  : Fri 29 Mar 2019 07:36:59 PM EDT
    Build Host  : lorax-f30
    Relocations : (not relocatable)
    URL         : https://github.com/bcl/extra-files
    Summary     : vhosts for nginx server
    Description :
    Created from https://github.com/bcl/extra-files, reference 'v1.0', on Fri Mar 29 19:36:57 2019


Push this new blueprint to composer by running `composer-cli blueprints push nginx-extra-vhosts.toml`,
and check to make sure it depsolves with `composer-cli blueprints depsolve nginx-extra-vhosts`.
If that is successful you can now build a `qcow2` image:

    composer-cli compose start nginx-extra-vhosts qcow2

And monitor the status using `composer-cli compose status`. When it is
finished, download the resulting image and boot it in a VM and login using the
credentials you specified in the blueprint.

`systemctl status nginx` should show the server is running, and you can test
the vhosts like this:

    [root@localhost ~]# curl -X "Host: one-site.myhost.com" http://127.0.0.1/

    <html>
        <head>
            <title>one-site.myhost.com</title>
        </head>
        <body>
            An example site
        </body>
    </html>

NOTES
-----

In the process of writing this post I found a bug, which is fixed in v31.2 of lorax. You
couldn't install the repo files to `/` because it was including the `/` directory in the rpm,
causing a conflict with the `filesystem` package. This has been fixed.

When using a destination of `/` you cannot include a dotfile directly under `/` because of how the
file copy works. It won't be installed and the compose will fail with an unpackaged files error.
You can include them under any other directory without problems, and they
will work just fine as long as the destination is set to a path other than `/`.
