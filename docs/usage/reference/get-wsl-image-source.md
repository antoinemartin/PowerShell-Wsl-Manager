# Get-WslImageSource

```text

NAME
    Get-WslImageSource

SYNOPSIS
    Gets the list of builtin WSL root filesystems from the local cache or remote repository.


SYNTAX
    Get-WslImageSource [[-Name] <String[]>] [[-Distribution] <String>] [[-Source] {Local | Builtin | Incus | Uri | Docker | All}] [[-Type] {Builtin | Incus | Local | Uri | Docker}] [-Configured] [-Sync] [<CommonParameters>]


DESCRIPTION
    The Get-WslImageSource cmdlet fetches the list of available builtin
    WSL root filesystems. It first updates the cache if needed using
    Update-WslBuiltinImageCache, then retrieves the images from the local database.

    This provides an up-to-date list of supported images that can be used
    to create WSL instances. The cmdlet implements intelligent caching with ETag
    support to reduce network requests and improve performance.


PARAMETERS
    -Name <String[]>

    -Distribution <String>

    -Source

    -Type
        Specifies the source type for fetching root filesystems. Must be of type
        WslImageType. Defaults to [WslImageType]::Builtin
        which points to the official repository of builtin images.

    -Configured [<SwitchParameter>]

    -Sync [<SwitchParameter>]
        Forces a synchronization with the remote repository, bypassing the local cache.
        When specified, the cmdlet will always fetch the latest data from the remote
        repository regardless of cache validity period and ETag headers.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslImageSource

    Gets all available builtin root filesystems, updating cache if needed.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImageSource -Type Builtin

    Explicitly gets builtin root filesystems from the builtins source.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImageSource -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache
    and ETag headers.




REMARKS
    To see the examples, type: "Get-Help Get-WslImageSource -Examples"
    For more information, type: "Get-Help Get-WslImageSource -Detailed"
    For technical information, type: "Get-Help Get-WslImageSource -Full"
    For online help, type: "Get-Help Get-WslImageSource -Online"


```
