# Update-WslImageSource

```text

NAME
    Update-WslImageSource

SYNOPSIS
    Updates a WSL image source with the latest information from its URL.


SYNTAX
    Update-WslImageSource [-ImageSource] <WslImageSource> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This function takes a WslImageSource object and updates its properties by fetching
    the latest distribution information from the source URL. The function supports
    WhatIf and Confirm parameters for safe execution.


PARAMETERS
    -ImageSource <WslImageSource>
        The WslImageSource object to update. This parameter is mandatory and accepts
        pipeline input.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Update-WslImageSource -ImageSource $myImageSource
    Updates the specified WSL image source with latest information from its URL.






    -------------------------- EXAMPLE 2 --------------------------

    PS > $imageSource | Update-WslImageSource -WhatIf
    Shows what would happen if the image source was updated without actually performing the update.






REMARKS
    To see the examples, type: "Get-Help Update-WslImageSource -Examples"
    For more information, type: "Get-Help Update-WslImageSource -Detailed"
    For technical information, type: "Get-Help Update-WslImageSource -Full"



```
