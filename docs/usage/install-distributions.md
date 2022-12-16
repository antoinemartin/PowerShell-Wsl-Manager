---
title: Install distrbutions
parent: Usage
layout: default
nav_order: 1
---

<!-- markdownlint-disable MD033 -->
<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>
<!-- markdownlint-enable MD033 -->

## Minimal distribution

The fastest distribution to install is the already configured Alpine:

```powershell
❯ install-wsl alpine1 -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1]...
####> Downloading  https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz...
####> Creating distribution [alpine1]...
####> Done. Command to enter distribution: wsl -d alpine1
```

Once the root filesystem is downloaded locally, subsequent installations are
even faster:

```powershell
PS❯ install-wsl alpine2 -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2]...
####> Alpine Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz].
####> Creating distribution [alpine2]...
####> Done. Command to enter distribution: wsl -d alpine2
PS❯ wsl -d alpine2
[powerlevel10k] fetching gitstatusd .. [ok]
wsl❯ exit
PS❯
```

`Get-Wsl` allows retrieving infomrmation about the installed distrbutions:

```powershell
❯ get-wsl alpine* | format-table -Property *

FileSystemPath BlockFile    Length Name      State Version Default Guid                                 BasePath
-------------- ---------    ------ ----      ----- ------- ------- ----                                 --------
\\wsl$\alpine2 ext4.vhdx 146800640 alpine2 Stopped       2   False 580da4f4-d3d3-4609-bd63-8b1120e8f792 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2
\\wsl$\alpine1 ext4.vhdx 146800640 alpine1 Stopped       2   False db7601cf-9cff-42ae-85c4-ab1ba516c118 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1
```

## Locally configured distribution

Installing a locally configured distribution allows starting from the official
distribution root filesystem that contains updated packages:

```powershell
PS❯ install-wsl ubuntu2210 -Distribution Ubuntu
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\ubuntu2210]...
####> Downloading https://cloud-images.ubuntu.com/wsl/kinetic/current/ubuntu-kinetic-wsl-amd64-wsl.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\ubuntu.rootfs.tar.gz...
####> Creating distribution [ubuntu2210]...
####> Running initialization script [configure.sh] on distribution [ubuntu2210]...
####> Done. Command to enter distribution: wsl -d ubuntu2210
PS❯ wsl -d ubuntu2210
[powerlevel10k] fetching gitstatusd .. [ok]
wsl❯ exit
PS❯
```

## LXD based distributions

[LXD] allows running linux system containers in Linux. It is similar to WSL as
it can use root filesystems as source. Canonical provides root filsystems for
the [most popular Linux distributions][lxd images]. The images built can be
browsed [here][lxd image list].

{: .warning }

LXD root filesystems may contain more packages than the ones needed for a
minimal WSL installation. However, they provide a reliable and centralized
source for Linux distributions.

{: .note }

The complete list of LXD images is available as a JSON file
[here][json lxd image list]. The image details are also available in this [json
file][json lxd images detail](caution: it is about 2Mbytes).

Let's imagine that we want to try the Alpine edge distribution. We can type:

```powershell
PS> install-wsl edge -Distribution lxd:alpine:edge
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\edge]...
####> Downloading https://uk.lxd.images.canonical.com/images/alpine/edge/amd64/default/20221213_13:02/rootfs.tar.xz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\lxd.alpine_edge.rootfs.tar.gz...
####> Creating distribution [edge]...
####> Running initialization script [configure.sh] on distribution [edge]...
####> Done. Command to enter distribution: wsl -d edge
PS> wsl -d edge
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(alpine) gid=1000(alpine) groups=10(wheel),1000(alpine)
❯ exit
PS>
```

[lxd images]: https://uk.lxd.images.canonical.com/
[lxd image list]: https://uk.lxd.images.canonical.com/images/
[lxd]: https://linuxcontainers.org/
[json lxd image list]: https://uk.lxd.images.canonical.com/streams/v1/index.json
[json lxd images detail]: https://uk.lxd.images.canonical.com/streams/v1/images.json
