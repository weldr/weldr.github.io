---

layout: post
title: "Pushing composed images to OpenStack"
author: stefw
tags: welder-web lorax-composer

---

Weldr aka. Composer can generate images suitable for uploading to OpenStack
cloud deployments, and starting instances there. The images have the right
layout, and include cloud-init.

## Prerequisites

We'll use [Fedora 29](https://getfedora.org/) as our OS of choice for running this. Run
this in its own VM with at least 8 gigabytes of memory and 40 gigabytes of disk space.
[Lorax](http://weldr.io/lorax/) makes some changes to the operating system its running on.

First install Composer:

    $ sudo yum install lorax-composer cockpit-composer cockpit composer-cli

Next make sure to turn off [SELinux](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/5/html/deployment_guide/ch-selinux) on the system. Lorax doesn't yet work properly with
SELinux running, as it installs an entire OS image in an alternate directory:

    $ sudo setenforce 0
    $ sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

Now enable and start ```lorax-composer``` system service:

    $ sudo systemctl enable --now lorax-composer.socket

If you're going to use [Cockpit](https://cockpit-project.org/) UI to drive Composer
(see below), you can also enable it like this:

    $ sudo systemctl enable --now cockpit.socket
    $ sudo firewall-cmd --add-service=cockpit && firewall-cmd --add-service=cockpit --permanent

## Compose an image from the UI

To compose an image in Composer, log into the *Cockpit Web Console* with your web browser.
It's running on port ```9090``` on the VM that you're running Composer in. Use any admin
or ```root``` Linux system credentials to log in.  Select the *Image Builder* tab.

![Cockpit Composer](/images/cockpit-composer-main.png)

We first have to have a *blueprint* defined. This blueprint describes what goes into the image.
For the purposes of this example we'll use the ```example-http-server``` blueprint, which
builds an image that contains a basic HTTP server.

Click on the *Create Image* button and choose *OpenStack QCOW2 Image* from the dropdown
to choose the *Image Type*:

![Create Image Openstack](/images/cockpit-composer-openstack-create.png)

If you click on the blueprint, you should see progress described on the Images tab:

![Create Image Progress](/images/cockpit-composer-openstack-progress.png)

Once it's done, download the image:

![Download Image](/images/cockpit-composer-openstack-download.png)

## Compose an image from the CLI

To compose an image in Composer from the command line, we first have to have a *blueprint*
defined. This blueprint describes what goes into the image. For the purposes of this
example we'll use the ```example-http-server``` blueprint, which builds an image that
contains a basic HTTP server.

We run the following command to start a compose. Notice that we pass the image type
of ```openstack``` which indicates we want an image appropriate for pushing to
*OpenStack*.

    $ sudo composer-cli compose start example-http-server openstack
    Compose 96268ffb-2c71-4e97-a855-7ac25e983a6e added to the queue

Now check the status of the compose like this:

    $ sudo composer-cli compose status
    96268ffb-2c71-4e97-a855-7ac25e983a6e RUNNING  Mon Oct  8 08:11:33 2018 example-http-server 0.0.1 openstack

In order to diagnose a failure or look for more detailed progress, see:

    $ sudo journalctl -fu lorax-composer
    ...

When it's done you can download the resulting image into the current directory:

    $ sudo composer-cli compose image 96268ffb-2c71-4e97-a855-7ac25e983a6e
    96268ffb-2c71-4e97-a855-7ac25e983a6e-disk.qcow2: 4460.00 MB

## Pushing and using the Image

The created *QCOW2* image can now be uploaded to *OpenStack* and used to start
an instance. Use the *Images* interface to do this:

![Upload Openstack Image](/images/openstack-upload-image.png)

You can now start an instance with that image:

![Upload Openstack Image](/images/openstack-start-instance.png)

Now you can run an instance using whatever mechanism you like (CLI or *AWS Console*)
from the snapshot. Use your private key via SSH to access the resulting EC2
instance as usual. The user to log in as is ```cloud-user```
