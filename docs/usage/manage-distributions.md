---
title: Manage distributions
parent: Usage
layout: default
nav_order: 2
---

<!-- markdownlint-disable MD033 -->
<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>
<!-- markdownlint-enable MD033 -->

## Get distributions by size

```bash
❯  Get-Wsl | Sort-Object -Property Length -Descending | Format-Table Name, @{Label="Size (MB)"; Expression={ $_.Length/1Mb }}, @{Label="File"; Expression={$_.BlockFile.FullName}}
Name                 Size (MB) File
----                 --------- ----
Ubuntu-20.04             87349 C:\Users\AntoineMartin\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu20.04onWindows_79rhkp1fndgsc\LocalState\ext4.vhdx
Arch                     33099 C:\Users\AntoineMartin\scoop\persist\archwsl\data\ext4.vhdx
godev                    32799 C:\Users\AntoineMartin\Documents\src\godev\ext4.vhdx
cm                       19518 C:\Users\AntoineMartin\AppData\Local\cm\ext4.vhdx
citest                    5983 C:\Users\AntoineMartin\AppData\Local\citest\ext4.vhdx
rancher-desktop-data      2409 C:\Users\AntoineMartin\AppData\Local\rancher-desktop\distro-data\ext4.vhdx
kaweezle                  2078 C:\Users\AntoineMartin\AppData\Local\kaweezle\kaweezle\ext4.vhdx
jekyll                     932 C:\Users\AntoineMartin\AppData\Local\Wsl\jekyll\ext4.vhdx
deb                        716 C:\Users\AntoineMartin\AppData\Local\Wsl\deb\ext4.vhdx
rancher-desktop            569 C:\Users\AntoineMartin\AppData\Local\rancher-desktop\distro\ext4.vhdx
```

## Get running distributions

```bash
❯ Get-Wsl -State Running
Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
deb    Running       2   False
godev  Running       2   False
```

## Stop all running distributions

{: .warning }

If a distribution is currently used in Visual Studio Code, you will be
disconnected.

```bash
❯ (Get-Wsl -State Running).Stop()
####> Stopping jekyll...[ok]
####> Stopping deb...[ok]
####> Stopping godev...[ok]
❯
```

## Remove distributions

To remove a single distribution, simply type:

```bash
❯ Uninstall-Wsl deb
```

You can use a wildcard to remove multiple distributions at the same time:

```bash
PS> Get-Wsl alpine*

Name      State Version Default
----      ----- ------- -------
alpine1 Stopped       2   False
alpine2 Stopped       2   False

# or get-wsl alpine* | uninstall-wsl
PS> uninstall-wsl alpine*
PS>
```

## Rename distribution

It may be handy to rename a distribution:

```bash

PS> rename-wsl jekyll2 jekyll
🎉 Distribution renamed to jekyll

Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
PS>
```

## Export distribution

An existing WSL distribution can be exported for reuse with the `Export-Wsl`
cmdlet:

```bash
PS> Export-Wsl jekyll
####> Exporting WSL distribution jekyll to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\jekyll.rootfs.tar...
####> Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\jekyll.rootfs.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\jekyll.rootfs.tar.gz...
####> Distribution jekyll saved to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\jekyll.rootfs.tar.gz.

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
   Local jekyll       3.19.1                 Synced jekyll.rootfs.tar.gz

PS>
```

The saved root filesystem can be reused to create a new WSL distribution:

```bash
PS> Install-Wsl jekyll2 -Distribution jekyll
####> Distribution directory [C:\Users\AntoineMartin\AppData\Local\Wsl\jekyll2] already exists.
####> [jekyll:3.19.1] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\jekyll.rootfs.tar.gz].
####> Creating distribution [jekyll2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\jekyll.rootfs.tar.gz]...
####> Done. Command to enter distribution: wsl -d jekyll2
PS>
```

## Stop distribution

To stop one or more running distributions, use the `Stop-Wsl` cmdlet:

```bash
PS> Stop-Wsl -Name
⌛ Stopping alpine322...
🎉 [ok]
⌛ Stopping alpine...
🎉 [ok]
```
