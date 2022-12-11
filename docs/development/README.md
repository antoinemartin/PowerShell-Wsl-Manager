---
title: Development
layout: default
permalink: /development
nav_order: 3
---

<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>

## Pre-requisites

To modify the module, you will need [git]. You can use [scoop] to install it.
Scoop will also allow you to install [vscode] that is the preferred development
envinronment.

## Getting started

To modify the module, first fork it on github and in clone your copy in your
local modules directory:

```powershell
❯ New-Item -Path $env:USERPROFILE\Documents\WindowsPowerShell\Modules -Force | Out-Null
❯ cd $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
❯ git clone https://github.com/<yourusername>/PowerShell-Wsl-Manager Wsl-Manager
```

The source code of the module is located in the `Wsl-Manager.psm1` file. After a
modification, you need to ensure that the previous version is not loaded in
memory by unloading the module with:

```powershell
❯ Remove-Module Wsl-Manager
❯
```

The loading of the new version is done automatically.

## Adding a new distro

Each distribution is made of two elements:

- The URL of the root fs.
- A configuration script.

The URL of the root fs is distro dependent, as well as the configuration script.

As part of the [Linux Containers] project, Canonical builds images for a wide 
range of Linux distributions. For each of them, it produces a root fs tarball.
All the images available can be seen in the [image list](https://uk.lxd.images.canonical.com/images/).
For each distribution we use the `default` subdirectory to avoid having the 
`cloud-init` dependencies.

{: .note }
The images may not be as minimal as the one we use, as they sometimes include 
packages that are not needed for WSL.

As an example, we will add the `Debian` distribution. As the time of this writing
the rootfs URL we find is the following: 

```
https://uk.lxd.images.canonical.com/images/debian/bullseye/amd64/default/20221211_05:24/rootfs.tar.xz
```

In the `Wsl-Manager.psm1` file, at the top of the file, the `$distributions` 
hastable defines the root filesystem urls for each distribution. 
add an entry with the name `Debian` and the above URL:


```powershell
$distributions = @{
    Arch   = @{
        Url             = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz'
        ConfiguredUrl   = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
    }
    Alpine = @{
        Url             = 'https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.0-x86_64.tar.gz'
        ConfiguredUrl   = ' https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
    }
    Ubuntu = @{
        Url             = 'https://cloud-images.ubuntu.com/wsl/kinetic/current/ubuntu-kinetic-wsl-amd64-wsl.rootfs.tar.gz'
        ConfiguredUrl   = ' https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
    }
    Debian = @{
        Url             = 'https://uk.lxd.images.canonical.com/images/debian/sid/amd64/default/20221211_05:24/rootfs.tar.xz'
    }
}
```

Then a `configure_debian.sh` configuration script needs to be added. As Ubuntu
is based on Debian, it can be created from the `configure_ubuntu.sh` script.

The differences are quite limited:

```diff
--- configure_ubuntu.sh
+++ configure_debian.sh
@@ -22,5 +22,5 @@
 
 apt update -qq
-apt install -qq -y zsh git sudo iproute2 gnupg socat openssh-client
+apt install -qq -y zsh git sudo iproute2 gnupg socat openssh-client curl
 apt-get clean
 
@@ -51,8 +51,8 @@
 gpg -k
 
-username="ubuntu"
+username="debian"
 if ! getent passwd $username; then
     /usr/sbin/useradd --comment '$username User' --create-home --user-group --uid 1000 --shell /bin/zsh --non-unique $username
-    /usr/sbin/usermod --groups admin $username
+    /usr/sbin/usermod --groups staff $username
     echo 'Defaults env_keep += "SSH_AUTH_SOCK"' >/etc/sudoers.d/10_$username
     echo "$username ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/10_$username
```

You can then install the new distribution:

```console
❯ Remove-Module Wsl-Manager
❯ install-wsl deb -Distribution Debian
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\deb]...
####> Downloading https://uk.lxd.images.canonical.com/images/debian/sid/amd64/default/20221211_05:24/rootfs.tar.xz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\debian.rootfs.tar.gz...
####> Creating distribution [deb]...
####> Running initialization script [configure_debian.sh] on distribution [deb]...
####> Done. Command to enter distribution: wsl -d deb
❯
```

[git]: https://git-scm.com/download/win
[scoop]: https://scoop.sh/
[vscode]: https://code.visualstudio.com/
[Linux Containers]: https://uk.lxd.images.canonical.com/

