---

layout: post
title: "Pushing composed images to AWS"
author: stefw
tags: welder-web lorax-composer

---

Weldr aka. Composer can generate images suitable for uploading to Amazon
Web Services, and starting an EC2 instance. The images have the right
partition layout, and include cloud-init.

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

Install the [AWS client](https://aws.amazon.com/cli/) tooling:

    $ sudo yum install python3-pip
    $ sudo pip3 install awscli

Make sure you have an *Access Key ID* configured in
[AWS IAM account manager](https://aws.amazon.com/iam/) and use that info to configure
the AWS command line client:

    $ aws configure
    AWS Access Key ID [None]: ............
    AWS Secret Access Key [None]: .............
    Default region name [None]: us-east-1
    Default output format [None]:

Make sure you have an appropriate [S3 bucket](https://aws.amazon.com/s3/). We've called
ours ```examplecomposer``` but yours must be globally unique, so you can't choose
the same name:

    $ BUCKET=composerredhat
    $ aws s3 mb s3://$BUCKET

![S3 bucket screenshot](/images/aws-s3-bucket-composerredhat.png)

If you haven't already, create a ```vmimport``` S3 *Role* in *IAM* and grant it
permissions to access *S3*.  This is how you do it from the command line:

    $ printf '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Principal": { "Service": "vmie.amazonaws.com" }, "Action": "sts:AssumeRole", "Condition": { "StringEquals":{ "sts:Externalid": "vmimport" } } } ] }' > trust-policy.json
    $ printf '{ "Version":"2012-10-17", "Statement":[ { "Effect":"Allow", "Action":[ "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket" ], "Resource":[ "arn:aws:s3:::%s", "arn:aws:s3:::%s/*" ] }, { "Effect":"Allow", "Action":[ "ec2:ModifySnapshotAttribute", "ec2:CopySnapshot", "ec2:RegisterImage", "ec2:Describe*" ], "Resource":"*" } ] }' $BUCKET $BUCKET > role-policy.json
    $ aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json
    $ aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json

![IAM vmimport role](/images/aws-iam-vmimport-role.png)

## Compose an image from the UI

To compose an image in Composer, log into the *Cockpit Web Console* with your web browser.
It's running on port ```9090``` on the VM that you're running Composer in. Use any admin
or ```root``` Linux system credentials to log in.  Select the *Image Builder* tab.

![Cockpit Composer](/images/cockpit-composer-main.png)

We first have to have a *blueprint* defined. This blueprint describes what goes into the image.
For the purposes of this example we'll use the ```example-http-server``` blueprint, which
builds an image that contains a basic HTTP server.

Click on the *Create Image* button and choose *Amazon Machine Image* from the dropdown
to choose the *Image Type*:

![Create Image AMI](/images/cockpit-composer-create-ami.png)

If you click on the blueprint, you should see progress described on the Images tab:

![Create Image Progress](/images/cockpit-composer-progress.png)

Once it's done, download the image:

![Download Image](/images/cockpit-composer-download.png)

## Compose an image from the CLI

To compose an image in Composer from the command line, we first have to have a *blueprint*
defined. This blueprint describes what goes into the image. For the purposes of this
example we'll use the ```example-http-server``` blueprint, which builds an image that
contains a basic HTTP server.

We run the following command to start a compose. Notice that we pass the image type
of ```ami``` which indicates we want an image appropriate for pushing to
*Amazon Web Services*.

    $ sudo composer-cli compose start example-http-server ami
    Compose 8db1b463-91ee-4fd9-8065-938924398428 added to the queue

Now check the status of the compose like this:

    $ sudo composer-cli compose status
    8db1b463-91ee-4fd9-8065-938924398428 RUNNING  Mon Oct  8 08:11:33 2018 example-http-server 0.0.1 ami

In order to diagnose a failure or look for more detailed progress, see:

    $ sudo journalctl -fu lorax-composer
    ...

When it's done you can download the resulting image into the current directory:

    $ sudo composer-cli compose image 8db1b463-91ee-4fd9-8065-938924398428
    8db1b463-91ee-4fd9-8065-938924398428-disk.ami: 4460.00 MB

## Pushing and using the image

So now you have an image created by composer, and sitting in the current working directory.
Here's how you push it to *S3* and start an *EC2* instance:

    $ AMI=8db1b463-91ee-4fd9-8065-938924398428-disk.ami
    $ aws s3 cp $AMI s3://$BUCKET
    Completed 24.2 MiB/4.4 GiB (2.5 MiB/s) with 1 file(s) remaining
    ...

Once the upload to *S3* completes, we import it as a snapshot into *EC2*:

    $ printf '{ "Description": "CentOS image", "Format": "raw", "UserBucket": { "S3Bucket": "%s", "S3Key": "%s" } }' $BUCKET $AMI > containers.json
    $ aws ec2 import-snapshot --disk-container file://containers.json

You can track the status of the import using the following command:

    $ aws ec2 describe-import-snapshot-tasks --filters Name=task-state,Values=active

Next create an image from the uploaded snapshot, by selecting the snapshot in the
*EC2* console, right clicking on it and selecting *Create Image*:

![Select Snapshot](/images/aws-ec2-select-snapshot.png)

Make sure to select the *Virtualization type* of *Hardware-assisted virtualization*
in the image you create:

![Create Image](/images/aws-ec2-create-image.png)

Now you can run an instance using whatever mechanism you like (CLI or *AWS Console*)
from the snapshot. Use your private key via SSH to access the resulting EC2
instance as usual. The user to log in as is ```ec2-user```
