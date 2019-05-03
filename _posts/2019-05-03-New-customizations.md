---
layout: post
title: New blueprint customizations in v31.4
author: bcl
tags: lorax-composer
---

In lorax-composer version 31.4 we have added the ability to setup a few more
things when the image is created. The [full documentation is
here](https://weldr.io/lorax/lorax-composer.html#customizations). It is now
possible to modify the [kernel boot cmdline](https://weldr.io/lorax/lorax-composer.html#customizations-kernel),
[set the timezone](https://weldr.io/lorax/lorax-composer.html#customizations-timezone),
[locale](https://weldr.io/lorax/lorax-composer.html#customizations-locale),
[open firewall ports](https://weldr.io/lorax/lorax-composer.html#customizations-firewall),
and [enable services](https://weldr.io/lorax/lorax-composer.html#customizations-services).

For example, now you can enable services so the symlink workaround I used
[in my post about repos.git]({% post_url 2019-03-28-Add-Files-From-Git-Repos %}) is
no longer necessary. You can add this to the blueprint to start nginx at boot time:

    [customizations.services]
    enabled = ["nginx"]

The `[customizations.firewall]` section lets you open up ports (or firewalld
services) in the firewall. To open ports 80 and 443 for use with a webserver
you would add this to your blueprint:

    [customizations.firewall]
    ports = ["80:tcp", "443:tcp"]

If you have suggestions for other customizations please [open an issue on
GitHub](https://github.com/weldr/lorax/issues) and we can discuss it. 

