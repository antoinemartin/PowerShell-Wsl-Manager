# Manage distributions

## Get distributions by size

```bash
❯  Get-WslInstance | Sort-Object -Property Length -Descending | Format-Table Name, @{Label="Size (MB)"; Expression={ $_.Length/1Mb }}, @{Label="File"; Expression={$_.BlockFile.FullName}}
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
❯ Get-WslInstance -State Running
Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
deb    Running       2   False
godev  Running       2   False
```

## Stop all running distributions

!!! warning

    If a distribution is currently used in Visual Studio Code, you will be
    disconnected.

```bash
PS> Stop-WslInstance *
⌛ Stopping base...
🎉 [ok]
⌛ Stopping goarch...
🎉 [ok]
⌛ Stopping alpine322...
🎉 [ok]
⌛ Stopping yawsldocker...
🎉 [ok]
⌛ Stopping jekyll...
🎉 [ok]
⌛ Stopping unowhy...
🎉 [ok]
⌛ Stopping iknite...
🎉 [ok]
⌛ Stopping openance...
🎉 [ok]
⌛ Stopping alpine...
🎉 [ok]
⌛ Stopping kaweezle...
🎉 [ok]
⌛ Stopping azure...
🎉 [ok]
PS>
```

## Remove distributions

To remove a single distribution, simply type:

```bash
❯ Remove-WslInstance deb
```

You can use a wildcard to remove multiple distributions at the same time:

```bash
PS> Get-WslInstance alpine*

Name      State Version Default
----      ----- ------- -------
alpine1 Stopped       2   False
alpine2 Stopped       2   False

# or Get-WslInstance alpine* | Remove-WslInstance
PS> Remove-WslInstance alpine*
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

An existing WSL distribution can be exported for reuse with the
`Export-WslInstance` cmdlet:

```bash
PS> Export-WslInstance jekyll
####> Exporting WSL distribution jekyll to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\jekyll.Image.tar...
####> Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\Image\jekyll.Image.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\jekyll.rootfs.tar.gz...
####> Distribution jekyll saved to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\jekyll.rootfs.tar.gz.

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
   Local jekyll       3.19.1                 Synced jekyll.rootfs.tar.gz

PS>
```

The saved image can be reused to create a new WSL distribution:

```bash
PS> New-WslInstance jekyll2 -From jekyll
####> Distribution directory [C:\Users\AntoineMartin\AppData\Local\Wsl\jekyll2] already exists.
####> [jekyll:3.19.1] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\jekyll.rootfs.tar.gz].
####> Creating distribution [jekyll2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\jekyll.rootfs.tar.gz]...
####> Done. Command to enter distribution: wsl -d jekyll2
PS>
```

## Stop distribution

To stop one or more running distributions, use the `Stop-WslInstance` cmdlet:

```bash
PS> Stop-WslInstance -Name
⌛ Stopping alpine322...
🎉 [ok]
⌛ Stopping alpine...
🎉 [ok]
```

## Change default user

To change the default user for a distribution, use the `Set-WslDefaultUid`
cmdlet:

```bash
PS> Set-WslDefaultUid -Name jekyll -Uid 1001
```

By default unconfigured distributions use the root user (UID 0). The user of
configured distributions is named after the OS name: `debian` for Debian,
`ubuntu` for Ubuntu, etc.

On some occasions, you may want to revert the default user to the root user
(UID 0) in order to launch services (docker) for instance.

You can do that by running the following command:

```bash
PS> Set-WslDefaultUid -Name docker -Uid 0
```
