## Pre-requisites

WSL 2 needs to be installed and working. If you are on Windows 11, running
`wsl --install` in the terminal should get you going.

To install this module, you need to be started with the
[PowerShell Gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.2).

The [powerlevel10k](https://github.com/romkatv/powerlevel10k) zsh theme comes
with a default configuration assuming that you are using a
[Nerd Font](https://www.nerdfonts.com/). As a starting point, we recommend using
the `Ubuntu Mono NF` font. It is available via [scoop](https://scoop.sh) in the
nerds font bucket:

```ps1con
PS> scoop bucket add nerd-fonts
PS> scoop install UbuntuMono-NF-Mono
```

Then replace the default font name in Windows Terminal with
`'UbuntuMono Nerd Font Mono'` (setting `profiles/defaults/font/face`). You can
do the same on Visual Studio Code (setting `editor.fontFamily`).

## Module installation

Install the module with:

```ps1con
PS> Install-Module -Name Wsl-Manager
```

## Create your first instance

Open a Windows Terminal and type:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance arch -From arch
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
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

The module performs the following operations:

- Creation of the Instance Directory in `$Env:LOCALAPPDATA\Wsl\`
- Downloading the Docker Image in `$Env:LOCALAPPDATA\Wsl\RootFS\`
- Creating the WSL Instance from the downloaded Docker image

You can enter the instance with:

```ps1con
PS> Invoke-WslInstance -In arch
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                                                20:51:51
❯ id
uid=1000(arch) gid=1000(arch) groups=1000(arch),998(wheel),999(adm)
❯ exit
PS>
```

You can see the installed instances with:

```ps1con
PS> Get-WslInstance
Name                                        State Version Default
----                                        ----- ------- -------
arch                                      Running       2   False
PS>
```

To uninstall the instance, just type:

```ps1con
PS> Remove-WslInstance arch
PS>
```

It will remove the instance and wipe its directory (in this case
`%LOCALAPPDATA%\Wsl\arch`). However the image will remain in the local cache. To
see the cached images, you can use the `Get-WslImage` cmdlet:

```ps1con
PS> Get-WslImage
Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
arch              Builtin Arch         2025.08.01   True                   Synced docker.arch.rootfs.tar.gz
PS>
```

## Image management

You can remove the local cache of an image with:

```ps1con
PS> Remove-WslImage arch
Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
arch              Builtin Arch         2025.08.01   True            NotDownloaded docker.arch.rootfs.tar.gz
PS>
```

The built-in distributions can be listed with:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslImage -Source Builtins
    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    ...
    PS>
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
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

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> # Several image names can be provided for download
    PS> Sync-WslImage alpine,alpine-base
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
    PS> # Several image names can be provided for download
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

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance test2 -From alpine-base
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
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

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> wsl -d test2
    # Show the user
    WSL> id
    ...
    # List the installed packages
    WSL> cat /etc/apk/world
    ...
    # Updgrade the system
    WSL> apk upgrade
    ...
    WSL> exit
    # Get the running instances
    PS> Get-WslInstance -State Running
    ...
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
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

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> nwsl test -From alpine | iwsl
    ...
    # Entering WSL
    WSL> exit
    # Get the running instance (test) and remove it with rmwsl (alias for Remove-WslInstance)
    PS> gwsl -State Running | rmwsl
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
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
`Get-Command -Module Wsl-Manager -CommandType Alias`. They are also listed in
the [Reference section](usage/reference/index.md)
