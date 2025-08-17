# Get-WslBuiltinRootFileSystem

```text

NAME
    Get-WslBuiltinRootFileSystem

SYNOPSIS
    Gets the list of builtin WSL root filesystems from the remote repository.


SYNTAX
    Get-WslBuiltinRootFileSystem [[-Name] <String>] [[-Url] <String>] [-Sync] [<CommonParameters>]


DESCRIPTION
    The Get-WslBuiltinRootFileSystem cmdlet fetches the list of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This provides an up-to-date list of supported distributions that can be used
    to create WSL distributions.

    The cmdlet downloads a JSON file from the remote repository and converts it
    into WslRootFileSystem objects that can be used with other Wsl-Manager commands.
    The cmdlet implements caching to reduce network requests and improve performance.
    Cached data is valid for 24 hours unless the -Sync parameter is used.


PARAMETERS
    -Name <String>
        Optional parameter to filter the results by distribution name. Supports wildcards.
        Default value is "*" which returns all available distributions.

        Required?                    false
        Position?                    1
        Default value                *
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Url <String>
        The URL to fetch the distributions JSON data from. Defaults to the official
        PowerShell-Wsl-Manager repository URL. This parameter allows for custom
        distribution sources if needed.

        Required?                    false
        Position?                    2
        Default value                https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/main/docs/assets/distributions.json
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Sync [<SwitchParameter>]
        Forces a synchronization with the remote repository, bypassing the local cache.
        When specified, the cmdlet will always fetch the latest data from the remote
        repository regardless of cache validity period.

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
        - The default URL points to: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/main/docs/assets/distributions.json
        - Returns null if the request fails or if no distributions are found
        - The Progress function is used to display download status
        - Uses HTTP ETag headers for efficient caching and conditional requests
        - Cache is stored in the WslRootFileSystem base path as "builtins.json"
        - Cache validity period is 24 hours (86400 seconds)

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslBuiltinRootFileSystem

    Gets all available builtin root filesystems from the default repository.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Name "Ubuntu*"

    Gets all Ubuntu-related builtin root filesystems using wildcard matching.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Name "Arch"

    Gets the specific Arch Linux builtin root filesystem.




    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Url "https://custom.repo/distributions.json"

    Gets builtin root filesystems from a custom repository URL.




    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache.





RELATED LINKS
    https://github.com/antoinemartin/PowerShell-Wsl-Manager



```
