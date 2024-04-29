---
title: Manage Root Filesystems
parent: Usage
layout: default
nav_order: 3
---

<!-- markdownlint-disable MD033 -->
<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>
<!-- markdownlint-enable MD033 -->

## Introduction

The root filesystems are located in `$env:LOCALAPPDATA\Wsl\RootFS`. Each root
file system is stored as a file with the `rootfs.tar.gz` suffix.

{: .warning }

Some root filesystems may be compressed with other formats than gunzip. However,
the file suffix is still `tar.gz` and WSL will recognize it.

Along with each root filesystem file, there is a json file containing metadata
information for the root filesystem. this file ends with the
`rootfs.tar.gz.json` suffix.

## Types of root filesystems

Root filesystems can currently be of the following types:

### Builtin

These are the filesystems that can be used by their name. Currently there is:

- [Archlinux]. As this is a _rolling_ distribution, there is no version
  attached. The current image used as base is 2024-04-01.
- [Alpine] (3.19)
- [Ubuntu] (24.04)
- [Debian] (bookworm)
- [OpenSuse] (tumbleweed). This is also a _rolling_ distribution.

Each of these distributions comes into 2 flavors: Unconfigured (the default) and
Configured. The configured version of the root filesystem has been already
configured through a [github actions workflow]

### LXD

[LXD], or linux containers, is a solution to run Linux system containers on a
Linux machine. It's somewhat like WSL for Linux, but with more features.
Canonical maintains root filesystems and images for a fair amount of linux
distributions (list [here](https://jenkins.linuxcontainers.org/view/Images/)).

The list of available LXD root filesystems can be obtained with the command:

```powershell
PS> Get-LXDRootFileSystem

Os              Release
--              -------
almalinux       8
almalinux       9
...
ubuntu          xenial
voidlinux       current
```

A LXD based WSL distribution can be created with `Install-Wsl` by passing a
distribution name with the form:

    lxd:<os>:<release>

for instance:

```powershell
PS> Install-Wsl test -Distribution lxd:rockylinux:9 -SkipConfigure
...
```

Wsl-Manager will fetch the root filesystem for the corresponding distro from
[https://uk.lxd.images.canonical.com/images](https://uk.lxd.images.canonical.com/images).

### Local

A local root filesystem is only available locally. It is the result of an
`Export-Wsl` command (more information
[here](../manage-distributions/#export-distribution)).

### Uri

The `Uri` type of distributions is for distributions that have been installed
from a URL. For instance:

```powershell
PS> Install-Wsl test -Distribution https://downloads.openwrt.org/releases/22.03.2/targets/x86/64/openwrt-22.03.2-x86-64-rootfs.tar.gz -SkipConfigure
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test]...
####> Downloading https://downloads.openwrt.org/releases/22.03.2/targets/x86/64/openwrt-22.03.2-x86-64-rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\openwrt-22.03.2-x86-64-rootfs.tar.gz...
####> Creating distribution [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\openwrt-22.03.2-x86-64-rootfs.tar.gz]...
####> Done. Command to enter distribution: wsl -d test
PS>  Get-WslRootFileSystem -Type Uri

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
     Uri openwrt      unknown                Synced openwrt-22.03.2-x86-64-rootfs...
PS>
```

## Get root filesystems

The list of root filesystems is given by the Get-WslRootFileSystem command:

```powershell
PS> Get-WslRootFileSystem

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Alpine       3.19                   Synced alpine.rootfs.tar.gz
 Builtin Arch         current                Synced arch.rootfs.tar.gz
 Builtin Debian       bookworm               Synced debian.rootfs.tar.gz
   Local Docker       unknown                Synced docker.rootfs.tar.gz
   Local jekyll       3.19.1                 Synced jekyll.rootfs.tar.gz
 Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
 Builtin Arch         current                Synced miniwsl.arch.rootfs.tar.gz
 Builtin Debian       bookworm               Synced miniwsl.debian.rootfs.tar.gz
 Builtin Opensuse     tumbleweed             Synced miniwsl.opensuse.rootfs.tar.gz
 Builtin Ubuntu       noble         NotDownloaded miniwsl.ubuntu.rootfs.tar.gz
   Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
 Builtin Opensuse     tumbleweed             Synced opensuse.rootfs.tar.gz
     Uri openwrt      unknown                Synced openwrt-22.03.2-x86-64-rootfs...
   Local Postgres     unknown                Synced postgres.rootfs.tar.gz
 Builtin Ubuntu       noble                Synced ubuntu.rootfs.tar.gz

PS>
```

Several filters are available (see
[reference](../command-reference/#get-wslrootfilesystem)), like:

```powershell
PS> Get-WslRootFileSystem -Os alpine

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Alpine       3.19                   Synced alpine.rootfs.tar.gz
 Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
```

## Synchronize root filesystems

Local Synchronization of root filesystems is performed with the
`Sync-WslRootFileSystem` cmdlet. For instance:

```powershell
PS> Sync-WslRootFileSystem -Distribution ubuntu -Configured
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.ubuntu.rootfs.tar.gz...
C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.ubuntu.rootfs.tar.gz
PS> Get-WslRootFileSystem -Os ubuntu

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Ubuntu       noble                Synced miniwsl.ubuntu.rootfs.tar.gz
 Builtin Ubuntu       noble                Synced ubuntu.rootfs.tar.gz
```

You can force the re-synchronization with the `-Force` switch. For instance, to
force re-synchronization of the builtin Alpine root filesystems:

```powershell
PS> Get-WslRootFileSystem -type builtin -Os alpine | Sync-WslRootFileSystem -Force
####> Downloading https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\alpine.rootfs.tar.gz...
C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\alpine.rootfs.tar.gz
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz...
C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz
PS>
```

## Remove Root filesystems

You can remove local root filesystems with the `Remove-WslRootFileSystem`
cmdlet:

```powershell
PS> Remove-WslRootFileSystem -Distribution opensuse

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Opensuse     tumbleweed      NotDownloaded opensuse.rootfs.tar.gz
```

It can accept the root filesystem through the pipe:

```powershell
PS> Get-WslRootFileSystem -Os opensuse | Remove-WslRootFileSystem

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Opensuse     tumbleweed      NotDownloaded miniwsl.opensuse.rootfs.tar.gz

PS> Get-WslRootFileSystem -Os opensuse

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Opensuse     tumbleweed      NotDownloaded miniwsl.opensuse.rootfs.tar.gz
 Builtin Opensuse     tumbleweed      NotDownloaded opensuse.rootfs.tar.gz
```

## Get root filesystems by size

You can order the present filesystem by size with the command:

```powershell
PS> Get-WslRootFileSystem -State Synced| Sort-Object -Property Length -Descending | Format-Table Type, Os, Release, AlreadyConfigured, @{Label="Size (MB)"; Expression={ [int]($_.Length/1Mb) }}

   Type Os       Release    AlreadyConfigured Size (MB)
   ---- --       -------    ----------------- ---------
  Local Netsdk   unknown                 True       477
  Local Docker   unknown                 True       465
Builtin Ubuntu   noble                False       429
  Local Postgres unknown                 True       361
Builtin Arch     current                 True       328
Builtin Arch     current                False       173
  Local jekyll   3.19.1                  True       168
Builtin Debian   bookworm                True       125
Builtin Opensuse tumbleweed              True        98
Builtin Opensuse tumbleweed             False        43
Builtin Debian   bookworm               False        32
Builtin Alpine   3.19                    True        26
Builtin Alpine   3.19                   False         3
```

<!-- prettier-ignore-start -->
[archlinux]: https://archlinux.org/
[alpine]: https://www.alpinelinux.org/
[ubuntu]: https://ubuntu.org
[debian]: https://debian.org
[opensuse]: https://www.opensuse.org
[github actions workflow]: https://github.com/antoinemartin/PowerShell-Wsl-Manager/blob/main/.github/workflows/build_custom_rootfs.yaml
[lxd]: https://linuxcontainers.org/lxd/introduction/
<!-- prettier-ignore-end -->
