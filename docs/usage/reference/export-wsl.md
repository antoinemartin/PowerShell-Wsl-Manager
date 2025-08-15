# Export-Wsl

```text

NAME
    Export-Wsl

SYNOPSIS
    Exports the file system of a WSL distribution.


SYNTAX
    Export-Wsl [-Name] <String> [[-OutputName] <String>] [-Destination <String>] [-OutputFile <String>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command exports the distribution and tries to compress it with
    the `gzip` command embedded in the distribution. If no destination file
    is given, it replaces the root filesystem file in the distribution
    directory.


PARAMETERS
    -Name <String>
        The name of the distribution.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -OutputName <String>
        Name of the output distribution. By default, uses the name of the
        distribution.

        Required?                    false
        Position?                    2
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Destination <String>
        Base directory where to save the root file system. Equals to
        $env:APPLOCALDATA\Wsl\RootFS (~\AppData\Local\Wsl\RootFS) by default.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -OutputFile <String>
        The name of the output file. If it is not specified, it will overwrite
        the root file system of the distribution.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -WhatIf [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Confirm [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS
    None.


OUTPUTS
    None.


NOTES


        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

    -------------------------- EXAMPLE 1 --------------------------

    PS > Install-Wsl toto
    wsl -d toto -u root apk add openrc docker
    Export-Wsl toto docker

    Uninstall-Wsl toto
    Install-Wsl toto -Distribution docker





RELATED LINKS
    Install-Wsl
    https://github.com/romkatv/powerlevel10k
    https://github.com/zsh-users/zsh-autosuggestions
    https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin



```
