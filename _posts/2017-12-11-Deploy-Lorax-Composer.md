---
layout: post
title: Deploying Welder Web with Lorax Composer and Docker
author: bcl
tags: lorax-composer docker
---

The Weldr project is made up of several components. This can make it difficult
for curious users to explore its capabilities without spending a bunch of time
setting up requirements. Docker can make this process easier (assuming that
you already have docker [setup and
running](https://www.docker.com/community-edition) on your system).

Weldr is currently a work in progress, with 2 main branches of development
joined together by a common web interface -- [Welder Web](https://github.com/weldr/welder-web)
running as a [Cockpit](http://cockpit-project.org/) plugin.
One branch is focusing on upstream work
using our own content store and depsolving([bdcs](https://github.com/weldr/bdcs)),
and the other branch is being developed for CentOS7 using a
modified version of the [Lorax project](https://github.com/rhinstaller/lorax)
called [Lorax Composer](https://github.com/rhinstaller/lorax/tree/lorax-composer).

In this post I will cover using the [Lorax
Composer](https://github.com/rhinstaller/lorax/tree/lorax-composer) API server
on CentOS7. A future post will describe the upstream API server
[bdcs-api](https://github.com/weldr/bdcs-api).

![Welder Web Screenshot]({{ "/assets/composer-screenshot.jpg" | absolute_url }})

The Dockerfile for this container is available [from github](https://github.com/weldr/docker-centos7-composer). Clone, build, and run the container like this:

    git clone https://github.com/weldr/docker-centos7-composer
    cd docker-centos7-composer
    sudo docker build -t weldr/centos7-composer .
    sudo docker run -it -v /sys/fs/cgroup:/sys/fs/cgroup:ro --security-opt="label:disable" -p 9090 --rm weldr/centos7-composer

You should now be able to connect to port 9090 of the docker container with
your web browser, login as root using the default password from the Dockerfile
(`ChangeThisLamePassword`). Click on the 'Welder' tab to see the list of
recipes and select one to view. Initial population of the components may take a
second or two while yum updates its metadata.

Explore the interface, some of it is still hard-coded, but you can create,
edit, save, and delete recipes. Select components to get more information about
them, and add or remove them from the recipe.

### Limitations

The current release does not allow you to build images yet, and some parts of the
user interface are static, but the recipe items should all be working.

## Behind The Scenes

If you take a look at the [Dockerfile](https://github.com/weldr/docker-centos7-composer/blob/master/Dockerfile)
you will see that, other than the basic
packages needed for a CentOS7 container, 3 other packages are being installed.
cockpit is part of the CentOS7 distribution and it provides a nice web
interface for managing your system. welder-web is actually a stand-alone
web application that has been slightly modified to work as a Cockpit plugin.

The bulk of the work is handled by lorax-composer which implements the API
server that Welder Web communicates with. Cockpit handles proxying
communication between the web browser and the API so that only the Cockpit port
needs to be open on the host. One part of the API is recipe storage. Recipes
are used to describe which packages will be included in the image being
created, and they are stored in git on the backend so that changes can be
easily tracked and reverted.

One of the primary differences between lorax-composer and bdcs-api is that the
depsolving in handled by yum instead of by
[bdcs](https://github.com/weldr/bdcs/). Currently it uses the yum repositories
setup on the host for this. But in a future release the user will be able to
add their own.

## The Future

Weldr is still a work in progress, and this Dockerfile should make it easier
for you to keep track of development. Check [the
repository](https://github.com/weldr/docker-centos7-composer/) for updates
and rerun the build steps to see what improvements have been made.

