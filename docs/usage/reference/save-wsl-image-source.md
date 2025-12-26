# Save-WslImageSource

```text

NAME
    Save-WslImageSource

SYNOPSIS
    Saves a WSL image source to the database.


SYNTAX
    Save-WslImageSource [-ImageSource] <WslImageSource> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    Saves an existing WslImageSource object to the WSL image database. If the ImageSource doesn't have an ID, a new GUID is generated. The function supports PowerShell's ShouldProcess pattern for safe execution.


PARAMETERS
    -ImageSource <WslImageSource>
        Specifies the WslImageSource object to save to the database.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > $imageSource = New-WslImageSource -Name "ubuntu-22.04"
    $imageSource | Save-WslImageSource

    Saves the WSL image source to the database.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImageSource -Name "ubuntu" | Save-WslImageSource -WhatIf

    Shows what would happen when saving Ubuntu image sources without actually performing the save.




    -------------------------- EXAMPLE 3 --------------------------

    PS > $imageSource = New-WslImageSource -Name "alpine"
    $imageSource.Configured = $true
    $imageSource | Save-WslImageSource -Verbose

    Saves an Alpine image source with verbose output after modifying its properties.




REMARKS
    To see the examples, type: "Get-Help Save-WslImageSource -Examples"
    For more information, type: "Get-Help Save-WslImageSource -Detailed"
    For technical information, type: "Get-Help Save-WslImageSource -Full"
    For online help, type: "Get-Help Save-WslImageSource -Online"


```
