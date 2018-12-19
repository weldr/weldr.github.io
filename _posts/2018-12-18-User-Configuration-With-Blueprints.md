---
layout: post
title: User Configuration with Blueprints
author: bcl
tags: lorax-composer
---

The images created by lorax-composer have the root account locked and no other
accounts included. This is to make sure that you cannot accidentally
build and deploy an image without a password. Currently the cockpit-composer GUI
does not support setting up users, but you can easily do this from the cmdline
using `composer-cli`.

First you need to save a copy of the blueprint you want to change by running
`composer-cli blueprints save example-http-server`. This will write the
blueprint in the current directory, with the `.toml` extension. The blueprint file is
formatted using [Tom's Obvious, Minimal
Language](https://github.com/toml-lang/toml), so editing it should be pretty
easy.

## Add a ssh key for root

Bump the version number by `0.0.1` to indicate a small change. To set the root
account's ssh key to the totally insecure Vagrant public key add a new
section at the end:

    [[customizations.user]]
    name = "root"
    key = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"

Push the new blueprint back to lorax-composer by running `composer-cli blueprints
push example-http-server.toml` and now any new images you build using the
`example-http-server` blueprint will include that key in the root account's
`.ssh/authorized_keys` file.

## Add an admin user

Bump the version number by another `0.0.1` and add another `customizations.user` section to the
bottom of the blueprint:

    [[customizations.user]]
    name = "admin"
    description = "Administrator account"
    password = "$6$FPgLqDGpQoPlPCU2$6PyHItjNrdOXwktFCl4cRnCE217G2VftpdDvz1AxTyq8cnD/5wwgr1ZXdRukHL5xRk4wfnVJ2tTXJjwmxUiiQ1"
    key = "PUBLIC SSH KEY"
    home = "/home/admin/"
    shell = "/usr/bin/bash"
    groups = ["dialout", "users", "wheel"]
    uid = 1200
    gid = 1200

This will create an admin account with a password and a ssh key. It also sets the home directory,
group membership, and uid/gid. You can generate a suitable password with this Python snippet:

    python3 -c "import crypt, getpass; print(crypt.crypt(getpass.getpass(), crypt.METHOD_SHA512))"

Type in the password at the `password:` prompt and paste the output into the
`password` field in the blueprint. Save the new copy of the blueprint and push
it to lorax-composer. Now any future builds will include the root ssh key and
an admin user.

If you don't include the uid/gid they will be set to the next available values available.

## Adding groups

You can also add new groups using `customizations.group` section.

    [[customizations.group]]
    name = "widget"
    gid = 1130

The gid is optional, the system will use the next available gid if it is not provided.

All of these customizations are [documented here](http://weldr.io/lorax/lorax-composer.html#customizations).



