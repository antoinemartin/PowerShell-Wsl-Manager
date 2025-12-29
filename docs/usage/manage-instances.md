# Manage instances

## Get instances by size

```ps1con
PS>  Get-WslInstance | Sort-Object -Property Length -Descending | Format-Table Name, @{Label="Size (MB)"; Expression={ $_.Length/1Mb }}, @{Label="File"; Expression={$_.BlockFile.FullName}}
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

## Get running instances

```ps1con
❯ Get-WslInstance -State Running
Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
deb    Running       2   False
godev  Running       2   False
```

## Stop all running instances

!!! warning

    If a instance is currently used in Visual Studio Code, you will be
    disconnected.

```ps1con
PS> # Also works with Stop-WslInstance *
PS> Get-WslInstance -State Running | Stop-WslInstance
Name                                        State Version Default
----                                        ----- ------- -------
jekyll                                    Stopped       2   False
deb                                       Stopped       2   False
godev                                     Stopped       2   False

PS>
```

## Remove instances

To remove a single instance, simply type:

```ps1con
❯ Remove-WslInstance deb
```

You can use a wildcard to remove multiple instances at the same time:

```ps1con
PS> Get-WslInstance alpine*

Name      State Version Default
----      ----- ------- -------
alpine1 Stopped       2   False
alpine2 Stopped       2   False

# or Get-WslInstance alpine* | Remove-WslInstance
PS> Remove-WslInstance alpine*
PS>
```

## Rename instance

It may be handy to rename a instance:

```ps1con

PS> Rename-Wsl jekyll2 jekyll
🎉 instance renamed to jekyll

Name     State Version Default
----     ----- ------- -------
jekyll Running       2   False
PS>
```

## Export instance

An existing WSL instance can be exported for reuse with the `Export-WslInstance`
cmdlet:

```ps1con
PS>  Export-Wsl jekyll
⌛ Exporting WSL instance jekyll as jekyll...

🎉 Instance jekyll saved to jekyll.

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
jekyll              Local Alpine       3.22.1       False                  Synced             159,0 MB

PS>
```

The saved image can be reused to create a new WSL instance:

```ps1con
PS> New-WslInstance jekyll2 -From jekyll
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\jekyll2]...
⌛ Creating instance [jekyll2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\915F68FD5C066BBAFA724FC34187601723BD84E13E00883D9671DF3D0C4A17DC.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In jekyll2 or wsl -d jekyll2

Name                                        State Version Default
----                                        ----- ------- -------
jekyll2                                   Stopped       2   False

PS>
```

## Change default user

By default unconfigured instances use the root user (UID 0). The user of
configured instances is named after the OS name: `debian` for Debian, `ubuntu`
for Ubuntu, etc with the Uid `1000`.

To change the default user for a instance, use the `Set-WslDefaultUid` cmdlet:

```ps1con
PS> Invoke-WslInstance -In jekyll -User root adduser '-s' /bin/zsh '-g' jekyll '-D' '-u' 1001 jekyll
PS> Set-WslDefaultUid -Name jekyll -Uid 1001 | iwsl
...(p10k configuration)...

New config: ~/.p10k.zsh.
Backup of ~/.zshrc: /tmp/.zshrc.XXXXEclcog.

See ~/.zshrc changes:

  diff /tmp/.zshrc.XXXXEclcog ~/.zshrc

File feature requests and bug reports at https://github.com/romkatv/powerlevel10k/issues

❯ id
uid=1001(jekyll) gid=1001(jekyll) groups=1001(jekyll)
  /mnt/c/Users/AntoineMartin                                                                                19:51:26
❯
```

On some occasions, you may want to revert the default user to the root user
(UID 0) in order to launch services (docker) for instance.

You can do that by running the following command:

```ps1con
PS> Set-WslDefaultUid -Name docker -Uid 0
```
