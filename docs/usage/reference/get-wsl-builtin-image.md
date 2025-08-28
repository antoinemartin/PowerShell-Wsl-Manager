# Get-WslBuiltinImage

```text

NAME
    Get-WslBuiltinImage

SYNOPSIS
    Gets the list of builtin WSL root filesystems from the remote repository.


SYNTAX
    Get-WslBuiltinImage [[-Source] {Local | Builtins | Incus | All}] [-Sync] [<CommonParameters>]


DESCRIPTION
    The Get-WslBuiltinImage cmdlet fetches the list of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This provides an up-to-date list of supported images that can be used
    to create WSL instances.

    The cmdlet downloads a JSON file from the remote repository and converts it
    into WslImage objects that can be used with other Wsl-Manager commands.
    The cmdlet implements intelligent caching with ETag support to reduce network
    requests and improve performance. Cached data is valid for 24 hours unless the
    -Sync parameter is used to force a refresh.


PARAMETERS
    -Source
        Specifies the source type for fetching root filesystems. Must be of type
        WslImageSource. Defaults to [WslImageSource]::Builtins
        which points to the official repository of builtin images.

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

    PS > Get-WslBuiltinImage

    Gets all available builtin root filesystems from the default repository source.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslBuiltinImage -Source Builtins

    Explicitly gets builtin root filesystems from the builtins source.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslBuiltinImage -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache
    and ETag headers.




REMARKS
    To see the examples, type: "Get-Help Get-WslBuiltinImage -Examples"
    For more information, type: "Get-Help Get-WslBuiltinImage -Detailed"
    For technical information, type: "Get-Help Get-WslBuiltinImage -Full"
    For online help, type: "Get-Help Get-WslBuiltinImage -Online"


```
