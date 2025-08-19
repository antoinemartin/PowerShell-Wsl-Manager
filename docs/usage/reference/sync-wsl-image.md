# Sync-WslImage

```text

NAME
    Sync-WslImage

SYNOPSIS
    Synchronize locally the specified WSL root filesystem.


SYNTAX
    Sync-WslImage [-Distribution] <String[]> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Sync-WslImage -Image <WslImage[]> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Sync-WslImage -Path <String> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    If the root filesystem is not already present locally, downloads it from its
    original URL.


PARAMETERS
    -Distribution <String[]>
        The identifier of the distribution. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu
        - Debian

        It also can be the URL (https://...) of an existing filesystem or a
        distribution name saved through Export-WslInstance.

        It can also be a name in the form:

            incus:<os>:<release> (ex: incus:rockylinux:9)

        In this case, it will fetch the last version the specified image in
        https://images.linuxcontainers.org/images.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Image <WslImage[]>
        The WslImage object to process.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -Path <String>

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Force [<SwitchParameter>]
        Force the synchronization even if the root filesystem is already present locally.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -WhatIf [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Confirm [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS
    The WslImage Objects to process.


OUTPUTS
    The path of the WSL root filesystem. It is suitable as input for the
    `wsl --import` command.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Sync-WslImage Alpine -Configured
    Syncs the already configured builtin Alpine root filesystem.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Sync-WslImage Alpine -Force
    Re-download the Alpine builtin root filesystem.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImage -State NotDownloaded -Os Alpine | Sync-WslImage
    Synchronize the Alpine root filesystems not already synced






    -------------------------- EXAMPLE 4 --------------------------

    PS > New-WslImage alpine -Configured | Sync-WslImage | % { &wsl --import test $env:LOCALAPPDATA\Wsl\test $_ }
    Create a WSL distro from a synchronized root filesystem.







RELATED LINKS
    New-WslImage
    Get-WslImage



```
