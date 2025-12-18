# Remove-WslImageSource

```text

NAME
    Remove-WslImageSource

SYNOPSIS
    Removes one or more WSL image sources from the local cache.


SYNTAX
    Remove-WslImageSource [-ImageSource] <WslImageSource[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslImageSource -Name <String[]> [-Type {Builtin | Incus | Local | Uri | Docker}] [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslImageSource -Id <Guid> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Remove-WslImageSource function removes WSL image sources from the local image
    database cache. It can remove sources by providing WslImageSource objects directly,
    by specifying source names with optional type filtering, or by GUID. The function
    only removes cached sources and will skip non-cached sources with a warning message.

    The function supports the ShouldProcess pattern, allowing -WhatIf and -Confirm
    parameters for safe operation.


PARAMETERS
    -ImageSource <WslImageSource[]>
        Specifies one or more WslImageSource objects to remove. This parameter accepts
        pipeline input and is used with the 'Source' parameter set.

    -Name <String[]>
        Specifies the name(s) of the image source(s) to remove. Supports wildcards for
        pattern matching. This parameter is used with the 'Name' parameter set and is
        mandatory when using this parameter set.

    -Type
        Specifies the type of WSL image to filter by when using the Name parameter.
        This parameter is optional and only applies to the 'Name' parameter set.

    -Id <Guid>
        Specifies the unique identifier (GUID) of the image source to remove. This
        parameter is mandatory when using the 'Id' parameter set.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Remove-WslImageSource -Name "Ubuntu*"

    Removes all cached WSL image sources with names starting with "Ubuntu".




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImageSource -Name "MyImage" | Remove-WslImageSource

    Gets a specific image source and pipes it to Remove-WslImageSource for removal.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Remove-WslImageSource -Name "Alpine" -Type Builtin

    Removes the cached builtin WSL image source named "Alpine".




    -------------------------- EXAMPLE 4 --------------------------

    PS > Remove-WslImageSource -Id "12345678-1234-1234-1234-123456789012"

    Removes the image source with the specified GUID.




    -------------------------- EXAMPLE 5 --------------------------

    PS > Remove-WslImageSource -Name "Debian*" -WhatIf

    Shows what would happen if the command runs without actually removing anything.




REMARKS
    To see the examples, type: "Get-Help Remove-WslImageSource -Examples"
    For more information, type: "Get-Help Remove-WslImageSource -Detailed"
    For technical information, type: "Get-Help Remove-WslImageSource -Full"



```
