# PowerShell-Wsl-Manager

[![codecov](https://codecov.io/github/antoinemartin/PowerShell-Wsl-Manager/graph/badge.svg?token=GGSLVWO0QG)](https://codecov.io/github/antoinemartin/PowerShell-Wsl-Manager)

Wsl-Manager is a Powershell module providing cmdlets to easily manage WSL
distributions, that we prefer to call instances. Currently, it can create a WSL
instance based on the following Linux distributions:

-   Archlinux (2025.08.01)
-   Alpine (3.22)
-   Ubuntu (25.10 questing)
-   Debian (13 trixie)
-   Any Incus available distribution
    ([list](https://images.linuxcontainers.org/images/))

It is available in PowerShell Gallery as the
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager) module.

Extended information is available in
[the project documentation](https://mrtn.me/PowerShell-Wsl-Manager/).

## Rationale

Windows is a great development platform for Linux based backend services through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl).

However, using a single WSL instance is unpractical as it tends to get bloated
and becomes difficult to recreate if configured manually.

It is much better to use an instance per development environment given that the
performance overhead is low (because all instances run on the same hidden
virtual machine).

**NOTE**: This is where the term _Distribution_ becomes confusing. We prefer to
call them _Instances_ because you can have multiple instances of the same Linux
distribution.

Creating a WSL instance from a Linux distribution Root filesystem
([Ubuntu](https://cloud-images.ubuntu.com/wsl/),
[Arch](https://archive.archlinux.org/iso/2025.08.01/),
[Alpine](https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/)) is
relatively easy but can rapidly become a tedious task.

That's where the `Wsl-Manager` module comes in. It allows managing root
filesystems and create WSL instances from them. We prefer to call the latter
them _Images_ as Wsl-Manager provides an experience that is similar to working
with Docker images.

## What it does

This module provides several cmdlets to manage images and instances. The ones
related to images (root filesystems) are named `<Verb>-WslImage` and those
related to instances (distros) are named `<Verb>-WslInstance`. For instance, the
main cmdlet for creating a new instance is called `New-WslInstance`.

`New-WslInstance` creates a WSL instance from an image (root filesystem). The
`Wsl-Manager` project provides a set of pre-configured lightweight images that
are configured as follows:

-   A user named after the type of distribution (`arch`, `alpine`, `ubuntu`,
    `debian` or `opensuse`) is set as the default user. The user as `sudo`
    (`doas` on Alpine) privileges.
-   zsh with [oh-my-zsh](https://ohmyz.sh/) is used as shell.
-   [powerlevel10k](https://github.com/romkatv/powerlevel10k) is set as the
    default oh-my-zsh theme.
-   [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
    plugin is installed.
-   The
    [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
    plugin is installed in order to use the GPG private keys available at the
    Windows level both for SSH and GPG (allowing global use of a Yubikey).

The project provides also _Base_ images with only the upstream root filesystem.
Those images can be used as a starting point for creating new WSL images. For
easier management, builtin images are provided as single layer docker images in
the github registry.

The images (gzipped tar root filesystems) from which the WSL instances are
created are cached in the `%LOCALAPPDATA%\Wsl\RootFS` directory when downloaded
and reused for further creations.

By default, each created WSL instance home folder (where the `ext4.vhdx` virtual
filesystem file is located) is located in `%LOCALAPPDATA%\Wsl`

## Pre-requisites

WSL 2 needs to be installed and working. If you are on Windows 11, running
`wsl --install` in the terminal should get you going.

To install this module, you need to be started with the
[PowerShell Gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.2).

The _builtins_ WSL images use a fancy zsh theme called
[powerlevel10k](https://github.com/romkatv/powerlevel10k) and come with a
default configuration assuming that you are using a
[Nerd Font](https://www.nerdfonts.com/). As a starting point, we recommend using
the `Ubuntu Mono NF` font. It is available via [scoop](scoop.sh) in the nerds
font bucket:

```bash
❯ scoop bucket add nerd-fonts
❯ scoop install UbuntuMono-NF-Mono
```

The font name is then `'UbuntuMono NF'` (for vscode, Windows Terminal...).

## Getting started

Install the module with:

```bash
❯ Install-Module -Name Wsl-Manager
```

And then create a WSL instance with:

```bash
PS>  New-WslInstance arch -From arch
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\arch]...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/arch:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/arch:latest from registry ghcr.io...
👀 Root filesystem size: 388,7 MB. Digest sha256:5cb3e1f7ab2e5cfb99454a80557974483fa5adb80434a9c3e7ac110efb3c4106. Downloading...
sha256:5cb3e1f7ab2e5cfb99454a80557974483fa5adb80434a9c3e7ac110efb3c4106 (388,7 MB) [==========================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.arch.rootfs.tar.gz.tmp. File size: 388,7 MB
🎉 [Arch:2025.08.01] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.arch.rootfs.tar.gz].
⌛ Creating instance [arch] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.arch.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In arch or wsl -d arch

Name                                        State Version Default
----                                        ----- ------- -------
arch                                      Stopped       2   False
PS>
```

You can enter the instance with:

```bash
PS> Invoke-WslInstance -In arch
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                                                20:51:51
❯ id
uid=1000(arch) gid=1000(arch) groups=1000(arch),998(wheel),999(adm)
❯ exit
PS>
```

You can see the installed instances with:

```bash
PS> Get-WslInstance
Name                                        State Version Default
----                                        ----- ------- -------
arch                                      Running       2   False
PS>
```

To uninstall the instance, just type:

```bash
PS> Remove-WslInstance arch
PS>
```

It will remove the instance and wipe its directory (in this case
`%LOCALAPPDATA%\Wsl\arch`). However the image will remain in the local cache. To
see the cached images, you can use the `Get-WslImage` cmdlet:

```bash
PS> Get-WslImage
Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
arch              Builtin Arch         2025.08.01   True                   Synced docker.arch.rootfs.tar.gz
PS>
```

You can remove the local cache of an image with:

```bash
PS> Remove-WslImage arch
Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
arch              Builtin Arch         2025.08.01   True            NotDownloaded docker.arch.rootfs.tar.gz
PS>
```

The built-in distributions can be listed with:

```bash
PS> Get-WslImage -Source Builtins

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
alpine            Builtin Alpine       3.22.1       True                   Synced docker.alpine.rootfs.tar.gz
alpine-base       Builtin Alpine       3.22.1       False                  Synced docker.alpine-base.rootfs.tar.gz
arch              Builtin Arch         2025.08.01   True            NotDownloaded docker.arch.rootfs.tar.gz
arch-base         Builtin Arch         2025.08.01   False           NotDownloaded docker.arch-base.rootfs.tar.gz
debian            Builtin Debian       13           True            NotDownloaded docker.debian.rootfs.tar.gz
debian-base       Builtin Debian       13           False           NotDownloaded docker.debian-base.rootfs.tar.gz
opensuse-tumb...  Builtin Opensuse-... 20250817     True            NotDownloaded docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250817     False           NotDownloaded docker.opensuse-tumbleweed-ba...
ubuntu            Builtin Ubuntu       25.10        True                   Synced docker.ubuntu.rootfs.tar.gz
ubuntu-base       Builtin Ubuntu       25.10        False           NotDownloaded docker.ubuntu-base.rootfs.tar.gz
PS>
```

You can sync both alpine images locally:

```bash
# Several image names can be provided for download
PS> Sync-WslImage alpine,alpine-base
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
👀 Root filesystem size: 35,4 MB. Digest sha256:8f5f9a84bf11de7ce1f74c9b335df99e321f72587c66ae2c0f8e0778e1d7b0b4. Downloading...
sha256:8f5f9a84bf11de7ce1f74c9b335df99e321f72587c66ae2c0f8e0778e1d7b0b4 (35,4 MB) [===========================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz.tmp. File size: 35,4 MB
🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
alpine            Builtin Alpine       3.22.1       True                   Synced docker.alpine.rootfs.tar.gz
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine-base:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine-base:latest from registry ghcr.io...
👀 Root filesystem size: 3,6 MB. Digest sha256:9824c27679d3b27c5e1cb00a73adb6f4f8d556994111c12db3c5d61a0c843df8. Downloading...
sha256:9824c27679d3b27c5e1cb00a73adb6f4f8d556994111c12db3c5d61a0c843df8 (3,6 MB) [============================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine-base.rootfs.tar.gz.tmp. File size: 3,6 MB
🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine-base.rootfs.tar.gz].
alpine-base       Builtin Alpine       3.22.1       False                  Synced docker.alpine-base.rootfs.tar.gz
```

And then create an unconfigured instance from the base alpine image:

```bash
PS> New-WslInstance test2 -From alpine-base
New-WslInstance test2 -From alpine-base
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
⌛ Creating instance [test2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine-base.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In test2 or wsl -d test2

Name                                        State Version Default
----                                        ----- ------- -------
test2                                     Stopped       2   False
PS>
```

As you can see, the download part is skipped when using an already cached image.

Then you can play with your new instance:

```bash
PS> wsl -d test2
# Show the user
WSL> id
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
# List the installed packages
WSL> cat /etc/apk/world
alpine-baselayout
alpine-keys
alpine-release
apk-tools
busybox
libc-utils
# Updgrade the system
WSL> apk upgrade
fetch https://dl-cdn.alpinelinux.org/alpine/v3.22/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.22/community/x86_64/APKINDEX.tar.gz
(1/5) Upgrading busybox (1.37.0-r18 -> 1.37.0-r19)
Executing busybox-1.37.0-r19.post-upgrade
(2/5) Upgrading busybox-binsh (1.37.0-r18 -> 1.37.0-r19)
(3/5) Upgrading libcrypto3 (3.5.1-r0 -> 3.5.2-r0)
(4/5) Upgrading libssl3 (3.5.1-r0 -> 3.5.2-r0)
(5/5) Upgrading ssl_client (1.37.0-r18 -> 1.37.0-r19)
Executing busybox-1.37.0-r19.trigger
OK: 7 MiB in 16 packages
# Returning to PowerShell
WSL> exit
# Get the running instances
PS> Get-WslInstance -State Running
Name                                        State Version Default
----                                        ----- ------- -------
test2                                     Running       2   False
```

## Cmdlet aliases

`Wsl-Manager` provides aliases for easier usage. For instance, to create a wsl
instance and enter it immediately, you can write:

<!-- cSpell: disable -->

```bash
PS> nwsl test -From alpine | iwsl
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test]...
⌛ Creating instance [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In test or wsl -d test
[powerlevel10k] fetching gitstatusd .. [ok]
WSL> exit
# Get the running instance (test) and remove it with rmwsl (alias for Remove-WslInstance)
PS> gwsl -State Running | rmwsl
```

<!-- cSpell: enable -->

All the available aliases can be found by running
`Get-Command -Module Wsl-Manager -CommandType Alias`.

## More Usage and examples

Extended usage and examples are available in
[the project documentation](https://mrtn.me/PowerShell-Wsl-Manager/).
