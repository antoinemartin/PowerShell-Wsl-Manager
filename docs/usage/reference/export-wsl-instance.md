# Export-WslInstance

```text

NAME
    Export-WslInstance

SYNOPSIS
    Exports the file system of a WSL distribution.


SYNTAX
    Export-WslInstance [-Name] <String> [[-OutputName] <String>] [-Destination <String>] [-OutputFile <String>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command exports the distribution and tries to compress it with
    the `gzip` command embedded in the distribution. If no destination file
    is given, it replaces the image file in the distribution
    directory.


PARAMETERS
    -Name <String>
        The name of the distribution.

    -OutputName <String>
        Name of the output distribution. By default, uses the name of the
        distribution.

    -Destination <String>
        Base directory where to save the root file system. Equals to
        $env:APPLOCALDATA\Wsl\Image (~\AppData\Local\Wsl\Image) by default.

    -OutputFile <String>
        The name of the output file. If it is not specified, it will overwrite
        the root file system of the distribution.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslInstance toto
    wsl -d toto -u root apk add openrc docker
    Export-WslInstance toto docker

    Remove-WslInstance toto
    New-WslInstance toto -From docker




REMARKS
    To see the examples, type: "Get-Help Export-WslInstance -Examples"
    For more information, type: "Get-Help Export-WslInstance -Detailed"
    For technical information, type: "Get-Help Export-WslInstance -Full"
    For online help, type: "Get-Help Export-WslInstance -Online"


```
