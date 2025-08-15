# Uninstall-Wsl

```text

NAME
    Uninstall-Wsl

SYNOPSIS
    Uninstalls WSL distribution.


SYNTAX
    Uninstall-Wsl [-Name] <String[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]

    Uninstall-Wsl -Distribution <WslDistribution[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command unregister the specified distribution. It also deletes the
    distribution base root filesystem and the directory of the distribution.


PARAMETERS
    -Name <String[]>
        The name of the distribution. Wildcards are permitted.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Distribution <WslDistribution[]>
        Specifies WslDistribution objects that represent the distributions to be removed.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -KeepDirectory [<SwitchParameter>]
        If specified, keep the distribution directory. This allows recreating
        the distribution from a saved root file system.

        Required?                    false
        Position?                    named
        Default value                False
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
    WslDistribution, System.String

    You can pipe a WslDistribution object retrieved by Get-Wsl,
    or a string that contains the distribution name to this cmdlet.


OUTPUTS
    None.


NOTES


        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

    -------------------------- EXAMPLE 1 --------------------------

    PS > Uninstall-Wsl toto

    Uninstall distribution named toto.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Uninstall-Wsl test*

    Uninstall all distributions which names start by test.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -State Stopped | Sort-Object -Property -Size -Last 1 | Uninstall-Wsl

    Uninstall the largest non running distribution.





RELATED LINKS
    Install-Wsl
    https://github.com/romkatv/powerlevel10k
    https://github.com/zsh-users/zsh-autosuggestions
    https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin



```
