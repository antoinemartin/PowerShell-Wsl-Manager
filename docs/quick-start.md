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
    👀 Root filesystem size: 378,7 MB. Digest sha256:b3e7f861649971544e8737803e7f4ad139e97fcf6af34e00db61c4a15df766e2. Downloading...
    sha256:b3e7f861649971544e8737803e7f4ad139e97fcf6af34e00db61c4a15df766e2 (378,7 MB) [=======================================================================================================================================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B0716C8EC7F926370A8E83278207995FDFB212412542634B5345162064965D22.rootfs.tar.gz.tmp. File size: 378,7 MB
    🎉 [Arch:2025.12.01] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B0716C8EC7F926370A8E83278207995FDFB212412542634B5345162064965D22.rootfs.tar.gz].
    ⌛ Creating instance [arch] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B0716C8EC7F926370A8E83278207995FDFB212412542634B5345162064965D22.rootfs.tar.gz]...
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
Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
arch              Builtin Arch         2025.12.01   True                   Synced             378,7 MB
PS>
```

## Image management

You can remove the local cache of an image with:

```ps1con
PS> Remove-WslImage arch
Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
arch              Builtin Arch         2025.12.01   True            NotDownloaded             375,9 MB

PS>
```

The built-in distributions can be listed with:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslImageSource -Source Builtins

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    ...
    PS>
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
    PS> Get-WslImageSource -Source Builtins

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3,5 MB 21/12/2025 11:16:44
    alpine            Builtin Alpine       3.23.2       True              35,5 MB 21/12/2025 11:16:44
    arch-base         Builtin Arch         2025.12.01   False            209,3 MB 21/12/2025 11:16:44
    arch              Builtin Arch         2025.12.01   True             375,9 MB 21/12/2025 11:16:44
    debian-base       Builtin Debian       13           False             29,4 MB 21/12/2025 11:16:44
    debian            Builtin Debian       13           True             141,7 MB 21/12/2025 11:16:44
    opensuse-tumb...  Builtin Opensuse-... 20251217     False             46,4 MB 21/12/2025 11:16:44
    opensuse-tumb...  Builtin Opensuse-... 20251217     True             108,6 MB 21/12/2025 11:16:44
    ubuntu-base       Builtin Ubuntu       26.04        False            377,6 MB 21/12/2025 11:16:44
    ubuntu            Builtin Ubuntu       26.04        True             430,8 MB 21/12/2025 11:16:44
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
    👀 Root filesystem size: 36,1 MB. Digest sha256:f9a746c7483d4df04350f166aec2e50a316240dd2c73383fa7614069d8a10bb3. Downloading...
    sha256:f9a746c7483d4df04350f166aec2e50a316240dd2c73383fa7614069d8a10bb3 (36,1 MB) [========================================================================================================================================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz.tmp. File size: 36,1 MB
    🎉 [Alpine:3.23.2] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz].

    Name                 Type Os           Release      Configured              State               Length
    ----                 ---- --           -------      ----------              -----               ------
    alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB
    ⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine-base:latest...
    ⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine-base:latest from registry ghcr.io...
    👀 Root filesystem size: 3,7 MB. Digest sha256:1074353eec0db2c1d81d5af2671e56e00cf5738486f5762609ea33d606f88612. Downloading...
    sha256:1074353eec0db2c1d81d5af2671e56e00cf5738486f5762609ea33d606f88612 (3,7 MB) [=========================================================================================================================================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B50BF42E519420CA2BE48DD0EFA22AA087C708D0602B67D413406533BEF9DAB5.rootfs.tar.gz.tmp. File size: 3,7 MB
    🎉 [Alpine:3.23.2] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B50BF42E519420CA2BE48DD0EFA22AA087C708D0602B67D413406533BEF9DAB5.rootfs.tar.gz].
    alpine-base       Builtin Alpine       3.23.2       False                  Synced               3,7 MB
    PS>
    ```

And then create an unconfigured instance from the base alpine image:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance test2 -From alpine-base
    ```

=== ":octicons-device-desktop-16: With Console output"

    ```ps1con
    PS> New-WslInstance test2 -From alpine-base
    ⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
    ⌛ Creating instance [test2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B50BF42E519420CA2BE48DD0EFA22AA087C708D0602B67D413406533BEF9DAB5.rootfs.tar.gz]...
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
    musl-utils
    # Updgrade the system
    WSL> apk upgrade
    OK: 8222 KiB in 16 packages
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
    ⌛ Creating instance [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz]...
    wsl: La prise en charge des VHD espacés est actuellement désactivée en raison d’un risque potentiel de corruption des données.
    Pour forcer une distribution à utiliser un VHD espacé, veuillez exécuter :
    wsl.exe --manage <DistributionName> --set-sparse --allow-unsafe
    🎉 Done. Command to enter instance: Invoke-WslInstance -In test or wsl -d test
    [powerlevel10k] fetching gitstatusd .. [ok]
      /mnt/c/Users/AntoineMartin
    WSL> exit
    # Get the running instance (test) and remove it with rmwsl (alias for Remove-WslInstance)
    PS> gwsl -State Running | rmwsl
    ```

<!-- cSpell: enable -->

All the available aliases can be found by running
`Get-Command -Module Wsl-Manager -CommandType Alias`. They are also listed in
the [Reference section](usage/reference/index.md)
