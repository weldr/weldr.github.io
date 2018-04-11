---
layout: post
title: Experimenting with Lorax Composer
author: bcl
tags: lorax-composer ansible
---

In my [previous post about Lorax Composer]({% post_url
2017-12-11-Deploy-Lorax-Composer %}) I said that the docker setup would be
useful for keeping track of the progress of the project. It ends up that isn't
true once you start composing images. livemedia-creator and lorax-composer
depend on [Anaconda](https://github.com/rhinstaller/anaconda) for actually
installing packages to the images. Because Anaconda depends on system
services like device-mapper, among other things, it isn't possible to use it
inside of a container. It needs a full system or a virtual machine.

The good news is that composing images from recipes has been added to [Lorax
Composer](https://github.com/rhinstaller/lorax/tree/lorax-composer) as of
v19.7.7-1. It currently only supports making a tar of the root filesystem, but
all the pieces are now in place, and the API has been
[documented](https://github.com/rhinstaller/lorax/blob/lorax-composer/src/pylorax/api/v0.py#L19).
The latest version, 19.7.9-1, is now available [from
COPR](https://copr.fedorainfracloud.org/coprs/g/weldr/lorax-composer/). It
includes new API routes for managing and downloading the images and several
bugfixes.

Another big change, also added in lorax-composer-19.7.7-1, is that communication
with the API is now through a Unix Domain Socket instead of over TCP. This
allows access to the API to be controlled using normal system user and group
management tools (eg. from within [Cockpit](http://cockpit-project.org/)), and
removes the need for adding a bunch of user management code to lorax-composer.
As long as the user is a member of the weldr group they will be able to connect
to the API via the socket at `/run/weldr/api.socket`.

In order to experiment with composing images you will need to setup a VM and
install lorax-composer. I've put together ansible playbook to make this easier.

## Install a Virtual Machine

Download a [CentOS7 installer image](https://centos.org/download/), and setup a
VM using your favorite virtualization system. I use KVM and virt-manager on a
CentOS7 host, but this should work fine with anything that provides a real
virtual machine. Not a container, so no Docker, LXC, systemd-nspawn, etc.

The VM should have at least 4G of RAM, 2 cores and more than 10G of disk space
(images can be quite large). More is better. And make sure to enable networking
from the installer's network page. If you don't you're going to have to enable
it after rebooting.

## Use Ansible to Setup the VM

Install [ansible](https://www.ansible.com) outside the VM, eg. on the VM host.
If you are running a rpm based distribution `yum install -y ansible` should be
sufficient. If you are using a Mac with brew `brew install ansible`,
or `pip install ansible` should work.

We will be using an ansible playbook to do all the hard work of installing
lorax-composer into the VM. The playbook and example recipes can be [found in
this github repository](https://github.com/weldr/ansible-centos7-composer). On
your VM host (not inside the VM), run:

    git clone https://github.com/weldr/ansible-centos7-composer
    cd ./ansible-centos7-composer

After your VM has rebooted figure out its IP address by
logging into its console and looking at the output of `ip a` or running `virsh
domifaddr <vm-name>` on the host system. Make sure you can ssh into the VM as
root, using password or key authentication.

From inside the ansible-centos7-composer directory on your VM host run the
[install-composer.yml](https://github.com/weldr/ansible-centos7-composer/blob/master/install-composer.yml)
playbook:

    ansible-playbook --ssh-extra-args "-o CheckHostIP=no -o StrictHostKeyChecking=no" -k -i <ip-of-the-vm>, install-composer.yml

If you are using ssh-key access to the VM you don't need the `-k`, just make sure
to ssh-add the key to your local ssh-agent first.

This will install cockpit, welder-web, and lorax-composer. Cockpit should be
available on port 9090 of the system. Note that welder-web does not support the
compose process yet, so while recipe editing will work, you will need to
trigger a compose from the VM's cmdline.

## Recipes

ssh into the VM as root and you can examine the example recipes:

    curl --unix-socket /run/weldr/api.socket http:///api/v0/recipes/list
    curl --unix-socket /run/weldr/api.socket http:///api/v0/recipes/info/http-server

Depsolve a recipe and see what packages will be installed:

    curl --unix-socket /run/weldr/api.socket http:///api/v0/recipes/depsolve/http-server

## Compose a root.tar.xz of the http-server Recipe

To compose a root filesystem in a tar you need to tell it which recipe you want
to use, and what the output type is. Supported output types are listed by the
`/compose/types` API route, but for now the only supported output it a tar. The
options are passed in the body of the POST as a JSON object. For example, to
create a tar of the http-server recipe you would run this from the VM's
cmdline:

    curl --unix-socket /run/weldr/api.socket -X POST -H "Content-Type: application/json" -d '{"recipe_name": "http-server", "compose_type": "tar", "branch": "master"}' http:///api/v0/compose

This will return some JSON with the UUID of the build, use this to monitor and download the results.

You can monitor the status of the build with:

    curl --unix-socket /run/weldr/api.socket http:///api/v0/compose/status/<uuid>

Or view the end of the anaconda.log with:

    curl --unix-socket /run/weldr/api.socket http:///api/v0/compose/log/<uuid>

Once the build has changed to the FINISHED state you can grab the output image:

    curl -OJ --unix-socket /run/weldr/api.socket http:///api/v0/compose/image/<uuid>

## Make a New Docker Image

You can then use this tar as the basis for a new Docker image. On a system with docker installed and
running you can import it:

    cat root.tar.xz | sudo docker import - welder/http-server

And then use it for a new httpd Docker image. As-is the root filesystem does not have httpd enabled so the
Dockerfile ends up being pretty simple:

    FROM welder/http-server:latest

    ENV container docker
    RUN systemctl enable httpd

    EXPOSE 80
    CMD ["/usr/sbin/init"]

Build it and run it with:

    sudo docker build -t welder/httpd .
    sudo docker run --rm -it welder/httpd

You should now be able to use a web browser to view the default CentOS webpage on the docker container's IP.

# Next Time

Next week I'll have a post with details on how you can help add output types to
lorax-composer. At its core it is using the same code as livemedia-creator so
adding disk images and iso's shouldn't take too much work.

