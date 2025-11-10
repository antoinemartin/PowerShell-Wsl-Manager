# Update-WslImageSource

```text

NAME
    Update-WslImageSource

SYNOPSIS
    Updates a WSL image source in the database.


SYNTAX
    Update-WslImageSource [-ImageSource] <WslImageSource> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    Updates an existing WslImageSource object in the WSL image database. If the ImageSource doesn't have an ID, a new GUID is generated. The function supports PowerShell's ShouldProcess pattern for safe execution.


PARAMETERS
    -ImageSource <WslImageSource>
        Specifies the WslImageSource object to update in the database.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > $imageSource = New-WslImageSource -Name "ubuntu-22.04"
    $imageSource | Update-WslImageSource

    Updates the WSL image source in the database.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImageSource -Name "ubuntu" | Update-WslImageSource -WhatIf

    Shows what would happen when updating Ubuntu image sources without actually performing the update.




    -------------------------- EXAMPLE 3 --------------------------

    PS > $imageSource = New-WslImageSource -Name "alpine"
    $imageSource.Configured = $true
    $imageSource | Update-WslImageSource -Verbose

    Updates an Alpine image source with verbose output after modifying its properties.




REMARKS
    To see the examples, type: "Get-Help Update-WslImageSource -Examples"
    For more information, type: "Get-Help Update-WslImageSource -Detailed"
    For technical information, type: "Get-Help Update-WslImageSource -Full"
    For online help, type: "Get-Help Update-WslImageSource -Online"


```
