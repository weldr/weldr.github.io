---

layout: post
title: "Pushing composed images to vSphere"
author: swalter
tags: welder-web lorax-composer

---

Weldr aka. Composer can generate images suitable for uploading to a VMWare
ESXi or vSphere system, and running as a virtual machine there. The images
have the right format, and include the necessary agents.

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

Now start ```lorax-composer``` system service:

    $ sudo systemctl enable --now lorax-composer.socket

If you're going to use [Cockpit](https://cockpit-project.org/) UI to drive Composer
(see below), you can also enable it like this:

    $ sudo systemctl enable --now cockpit.socket
    $ sudo firewall-cmd --add-service=cockpit && firewall-cmd --add-service=cockpit --permanent

## Compose an image from the CLI

To compose an image in Composer from the command line, we first have to have a *blueprint*
defined. This blueprint describes what goes into the image. For the purposes of this
example we'll use the ```example-http-server``` blueprint, which builds an image that
contains a basic HTTP server.

Because VMWare deployments typically does not have ```cloud-init``` configured to
inject user credentials to virtual machines, we must perform that task ourselves on
the blueprint. Use the following command to extract the blueprint to a ```example-http-server.toml```
file in the current directory:

    $ composer-cli blueprints save example-http-server

Add the following lines to the end of the ```example-http-server.toml``` file to set
the initial root ```password``` to ```foobar```. You can also use a crypted password
string for the ```password``` or set an SSH ```key```.

    [[customizations.user]]
    name = "root"
    password = "foobar"
    key = "..."

Now save the blueprint back into composer with the following command:

    $ composer-cli blueprints push example-http-server.toml

We run the following command to start a compose. Notice that we pass the image type
of ```vmdk``` which indicates we want an image appropriate for pushing to
*VMWare* in the *Virtual Machine Disk* format.

    $ sudo composer-cli compose start example-http-server vmdk
    Compose 55070ff6-d637-40fe-80f9-9518f2ee0f21 added to the queue

Now check the status of the compose like this:

    $ sudo composer-cli compose status
    55070ff6-d637-40fe-80f9-9518f2ee0f21 RUNNING  Mon Oct  8 11:40:50 2018 example-http-server 0.0.1 vmdk

In order to diagnose a failure or look for more detailed progress, see:

    $ sudo journalctl -fu lorax-composer
    ...

When it's done you can download the resulting image into the current directory:

    $ sudo composer-cli compose image 55070ff6-d637-40fe-80f9-9518f2ee0f21
    55070ff6-d637-40fe-80f9-9518f2ee0f21-disk.ami: 4460.00 MB

## Pushing and using the image

You can upload the image into vSphere via HTTP, or by pushing it into your shared
VMWare storage. We'll use the former mechanism. Click on *Upload Files' in the vCenter:

![Upload files](/images/vmware-upload-image.png)

When you create a VM, on the *Device Configuration*, delete the default *New Hard Disk*
and use the drop down to select an *Existing Hard Disk* disk image:

![Disk Image Selection](/images/vmware-existing-disk.png)

And lastly, make sure you use an *IDE* device as the *Virtual Device Node* for the
disk you create. The default is *SCSI*, which will result in an unbootable virtual
machine.
![Disk Image Selection](/images/vmware-existing-ide.png)

