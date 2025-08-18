# Get-WslBuiltinRootFileSystem

```text

NAME
    Get-WslBuiltinRootFileSystem

SYNOPSIS
    Gets the list of builtin WSL root filesystems from the remote repository.


SYNTAX
    Get-WslBuiltinRootFileSystem [[-Source] {Local | Builtins | Incus | All}] [-Sync] [<CommonParameters>]


DESCRIPTION
    The Get-WslBuiltinRootFileSystem cmdlet fetches the list of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This provides an up-to-date list of supported distributions that can be used
    to create WSL distributions.

    The cmdlet downloads a JSON file from the remote repository and converts it
    into WslRootFileSystem objects that can be used with other Wsl-Manager commands.
    The cmdlet implements intelligent caching with ETag support to reduce network
    requests and improve performance. Cached data is valid for 24 hours unless the
    -Sync parameter is used to force a refresh.


PARAMETERS
    -Source
        Specifies the source type for fetching root filesystems. Must be of type
        WslRootFileSystemSource. Defaults to [WslRootFileSystemSource]::Builtins
        which points to the official repository of builtin distributions.

        Required?                    false
        Position?                    1
        Default value                Builtins
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Sync [<SwitchParameter>]
        Forces a synchronization with the remote repository, bypassing the local cache.
        When specified, the cmdlet will always fetch the latest data from the remote
        repository regardless of cache validity period and ETag headers.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS
    None. You cannot pipe objects to Get-WslBuiltinRootFileSystem.


OUTPUTS
    WslRootFileSystem[]
    Returns an array of WslRootFileSystem objects representing the available
    builtin distributions.


NOTES


        - This cmdlet requires an internet connection to fetch data from the remote repository
        - The source URL is determined by the WslRootFileSystemSources hashtable using the Source parameter
        - Returns null if the request fails or if no distributions are found
        - The Progress function is used to display download status during network operations
        - Uses HTTP ETag headers for efficient caching and conditional requests (304 responses)
        - Cache is stored in the WslRootFileSystem base path with filename from the URI
        - Cache validity period is 24 hours (86400 seconds)
        - In-memory cache (WslRootFileSystemCacheFileCache) is used alongside file-based cache
        - ETag support allows for efficient cache validation without re-downloading unchanged data

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslBuiltinRootFileSystem

    Gets all available builtin root filesystems from the default repository source.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Source Builtins

    Explicitly gets builtin root filesystems from the builtins source.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache
    and ETag headers.





RELATED LINKS
    https://github.com/antoinemartin/PowerShell-Wsl-Manager



```
