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
        WslImageType. Defaults to [WslImageType]::Builtin
        which points to the official repository of builtin images.

    -Sync [<SwitchParameter>]
        Forces a synchronization with the remote repository, bypassing the local cache.
        When specified, the cmdlet will always fetch the latest data from the remote
        repository regardless of cache validity period and ETag headers.

    -Force [<SwitchParameter>]

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

    PS > Update-WslBuiltinImageCache -Type Builtin -Sync

    Forces a fresh update of builtin root filesystems cache, ignoring local cache
    and ETag headers.




REMARKS
    To see the examples, type: "Get-Help Update-WslBuiltinImageCache -Examples"
    For more information, type: "Get-Help Update-WslBuiltinImageCache -Detailed"
    For technical information, type: "Get-Help Update-WslBuiltinImageCache -Full"
    For online help, type: "Get-Help Update-WslBuiltinImageCache -Online"


```
