# Get-WslBuiltinRootFileSystem

```text

NAME
    Get-WslBuiltinRootFileSystem

SYNOPSIS
    Gets the list of builtin WSL root filesystems from the remote repository.


SYNTAX
    Get-WslBuiltinRootFileSystem [[-Name] <String>] [<CommonParameters>]


DESCRIPTION
    The Get-WslBuiltinRootFileSystem cmdlet fetches the list of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This provides an up-to-date list of supported distributions that can be used
    to create WSL distributions.

    The returned data structure is similar to the local Distributions.psd1 file
    but reflects the latest available distributions from the remote source.


PARAMETERS
    -Name <String>
        Optional parameter to filter the results by distribution name. Supports wildcards.

        Required?                    false
        Position?                    1
        Default value                *
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS

OUTPUTS

NOTES


        This cmdlet requires an internet connection to fetch the latest data from
        https://mrtn.me/PowerShell-Wsl-Manager/assets/distributions.json

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslBuiltinRootFileSystem
    Gets all available builtin root filesystems.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Name "Ubuntu*"
    Gets all Ubuntu-related builtin root filesystems.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslBuiltinRootFileSystem -Name "Arch"
    Gets the specific Arch builtin root filesystem.







RELATED LINKS



```
