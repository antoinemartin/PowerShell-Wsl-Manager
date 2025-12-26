# Update-WslBuiltinImageCache

```text

NAME
    Update-WslBuiltinImageCache

SYNOPSIS
    Updates the cache of builtin WSL root filesystems from the remote repository.


SYNTAX
    Update-WslBuiltinImageCache [[-Type] {Builtin | Incus | Local | Uri | Docker}] [-Sync] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Update-WslBuiltinImageCache cmdlet updates the local cache of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This function handles the network operations and database updates for image metadata.

    The cmdlet implements intelligent caching with ETag support to reduce network
    requests and improve performance. Cached data is valid for 24 hours unless the
    -Sync parameter is used to force a refresh.


PARAMETERS
    -Type
        Specifies the source type for fetching root filesystems. Must be of type
        WslImageType. Defaults to [WslImageType]::Builtin. Valid values are Builtin
        and Incus which point to their respective official repositories.

    -Sync [<SwitchParameter>]
        Forces a synchronization with the remote repository, bypassing the local cache
        validity check. When specified, the cmdlet will fetch the latest data from the
        remote repository using ETag headers if available.

    -Force [<SwitchParameter>]
        Forces a complete refresh ignoring both cache validity and ETag headers. When
        specified, the cmdlet will always download fresh data from the remote repository.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Update-WslBuiltinImageCache

    Updates the cache for builtin root filesystems from the default repository source.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Update-WslBuiltinImageCache -Type Incus -Sync

    Forces a cache update for Incus root filesystems, using ETag validation.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Update-WslBuiltinImageCache -Type Builtin -Force

    Forces a complete refresh of builtin root filesystems cache, ignoring both cache
    validity and ETag headers.




REMARKS
    To see the examples, type: "Get-Help Update-WslBuiltinImageCache -Examples"
    For more information, type: "Get-Help Update-WslBuiltinImageCache -Detailed"
    For technical information, type: "Get-Help Update-WslBuiltinImageCache -Full"
    For online help, type: "Get-Help Update-WslBuiltinImageCache -Online"


```
