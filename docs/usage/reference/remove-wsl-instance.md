# Remove-WslInstance

```text

NAME
    Remove-WslInstance

SYNOPSIS
    Removes WSL instance.


SYNTAX
    Remove-WslInstance [-Name] <String[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslInstance -Instance <WslInstance[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command remove the specified instance. It also deletes the
    instance vhdx file and the directory of the instance. It's the
    equivalent of `wsl --unregister`.


PARAMETERS
    -Name <String[]>
        The name of the instance. Wildcards are permitted.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Instance <WslInstance[]>
        Specifies WslInstance objects that represent the instances to be removed.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -KeepDirectory [<SwitchParameter>]
        If specified, keep the instance directory. This allows recreating
        the instance from a saved image.

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
    WslInstance, System.String

    You can pipe a WslInstance object retrieved by Get-WslInstance,
    or a string that contains the instance name to this cmdlet.


OUTPUTS
    None.


NOTES


        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

    -------------------------- EXAMPLE 1 --------------------------

    PS > UnNew-WslInstance toto

    Uninstall distribution named toto.




    -------------------------- EXAMPLE 2 --------------------------

    PS > UnNew-WslInstance test*

    Uninstall all distributions which names start by test.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslInstance -State Stopped | Sort-Object -Property -Size -Last 1 | UnNew-WslInstance

    Uninstall the largest non running distribution.





RELATED LINKS
    New-WslInstance
    https://github.com/romkatv/powerlevel10k
    https://github.com/zsh-users/zsh-autosuggestions
    https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin



```
