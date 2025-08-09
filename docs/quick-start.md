---
layout: default
title: Quick Start
nav_order: 2
---

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
####> Running initialization script [configure.sh] on distribution [dev]...
####> Done. Command to enter distribution: wsl -d dev
❯
```

To uninstall the distribution, just type:

```console
❯ Uninstall-Wsl dev
❯
```

It will remove the distribution and wipe the directory completely.

## Using already configured Filesystems

Configuration implies installing some packages. To avoid the time taken to
download and install such packages, Already configured root filesystems files
are made available on
[github](https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/tag/latest).

You can install an already configured distribution by adding the `-Configured`
switch:

```powershell
❯ install-wsl test2 -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
####> Downloading  https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz...
####> Creating distribution [test2]...
####> Done. Command to enter distribution: wsl -d test2
❯
```
