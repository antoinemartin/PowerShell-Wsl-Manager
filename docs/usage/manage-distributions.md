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

## Get distrbutions by size

```powershell
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

## Get running distrbutions

```powershell
❯ Get-Wsl -State Running
Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
deb    Running       2   False
godev  Running       2   False
```

## Stop all running distributions

{: .warning }

If a distrbution is currently used in Visual Studio Code, you will be
disconnected.

```powershell
❯ (Get-Wsl -State Running).Stop()
####> Stopping jekyll...[ok]
####> Stopping deb...[ok]
####> Stopping godev...[ok]
❯
```

## Remove distributions

To remove a single distrbution, simply type:

```powershell
❯ Uninstall-Wsl deb
```

You can use a wildcard to remove multiple distrbutions at the same time:

```powershell
❯ Get-Wsl alpine*

Name      State Version Default
----      ----- ------- -------
alpine1 Stopped       2   False
alpine2 Stopped       2   False

# or get-wsl alpine* | uninstall-wsl
❯ uninstall-wsl alpine*
❯
```

## Rename distribution

It may be handy to rename a distrbution:

```powershell

PS> (Get-wsl jekyll2).Rename('jekyll')
PS> Get-Wsl jekyll

Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
PS❯
```
