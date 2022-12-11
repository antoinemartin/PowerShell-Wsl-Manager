---
layout: home
title: Introduction
nav_order: 1
permalink: /
---

Wsl-Manager is a Powershell cmdlet to quickly create a minimal WSL distribution.
Currently, it can create an Archlinux, Alpine (3.17) or Ubuntu (22.10) based
distribution. It is available in PowerShell Gallery as
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager/1.2.0).

This project is generalization of its sister project
[PowerShell-Wsl-Alpine](https://github.com/antoinemartin/PowerShell-Wsl-Alpine).

## Rationale

Windows is a great development platform for Linux based backend services through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl).

However, using a single Linux distrbution is unpratictal as it tends to get
bloated and becomes difficult to recreate if configured manually.

It is much better to use a distribution per development envinronment given that
the performance overhead is low.

Creating a WSL distribution from a Linux distro Root filesystem
([Ubuntu](https://cloud-images.ubuntu.com/wsl/),
[Arch](https://archive.archlinux.org/iso/2022.12.01/),
[Alpine](https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/)) is
relatively easy but can rapidely become a tedious task.

The `Wsl-Manager` module streamlines that.

## What it does

This module allows to easily create and manage lightweight WSL distributions. It
provides support for the following distros:

- [Alpine (3.17)](https://www.alpinelinux.org/) is the lightest and allows
  developing in the same environment as most docker containers.
- [Arch Linux](https://archlinux.org/) is the most up to date and versatile.
- [Ubunty (22.10)](https://ubuntu.com/) is the most used. In particular, it
  allows simulating the Github Actions runner.

It provides a cmdlet called `Install-Wsl` that will install a lightweight
Windows Subsystem for Linux (WSL) distribution.

The installed distribution is configured as follows:

- A user named after the type of distribution (`arch`, `alpine` or `ubuntu`) is
  set as the default user. The user as `sudo` (`doas` on Alpine) privileges.
- zsh with [oh-my-zsh](https://ohmyz.sh/) is used as shell.
- [powerlevel10k](https://github.com/romkatv/powerlevel10k) is set as the
  default oh-my-zsh theme.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin
  is installed.
- The
  [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
  plugin is installed in order to use the GPG private keys available at the
  Windows level both for SSH and GPG (I personally use a Yubikey).

You can install an already configured distribution (`-Configured` flag) or start
from the official root filesystem and perform the configuration locally on the
newly created distrbution.

The root filesystems from which the WSL distributions are created are cached in
the `%LOCALAPPDATA%\Wsl\RootFS` directory when downloaded and reused for further
creations.

By default, each created WSL distribution home folder (where the `ext4.vhdx`
virtual filesystem file is located) is located in `%LOCALAPPDATA%\Wsl`

## Pre-requisites

WSL 2 needs to be installed and working. If you are on Windows 11, a simple
`wsl --install` should get you going.

To install this module, you need to be started with the
[PowerShell Gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.2).

The WSL distribution uses a fancy zsh theme called
[powerlevel10k](https://github.com/romkatv/powerlevel10k). To work properly in
the default configuration, you need a [Nerd Font](https://www.nerdfonts.com/).
My personal advice is to use `Ubuntu Mono NF` available via [scoop](scoop.sh) in
the nerds font bucket:

```console
❯ scoop bucket add nerd-fonts
❯ scoop install UbuntuMono-NF-Mono
```

The font name is then `'UbuntuMono NF'` (for vscode, Windows Terminal...).

## Getting started

Install the module with:

```console
❯ Install-Module -Name Wsl-Manager
```

And then create a WSL distribution with:

```console
❯ Install-Wsl Arch -Distribution Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\dev]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz...
####> Creating distribution [dev]...
####> Running initialization script [configure_arch.sh] on distribution [dev]...
####> Done. Command to enter distribution: wsl -d dev
❯
```

To uninstall the distribution, just type:

```console
❯ Uninstall-Wsl dev
❯
```

It will remove the distrbution and wipe the directory completely.

## Using already configured Filesystems

Configuration implies installing some packages. To avoid the time taken to
download and install such packages, Already configured root filesystems files
are made available on
[github](https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/tag/latest).

You can install an already configured distrbution by adding the `-Configured`
switch:

```powershell
❯ install-wsl test2 -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
####> Downloading  https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz...
####> Creating distribution [test2]...
####> Done. Command to enter distribution: wsl -d test2
❯
```
