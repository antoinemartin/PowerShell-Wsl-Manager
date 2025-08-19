## Pre-requisites

To modify the module, you will need [git]. You can use [scoop] to install it.
Scoop will also allow you to install [vscode] that is the preferred development
environment.

## Getting started

To modify the module, first fork it on github and in clone your copy in your
local modules directory:

```bash
❯ New-Item -Path $env:USERPROFILE\Documents\WindowsPowerShell\Modules -Force | Out-Null
❯ cd $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
❯ git clone https://github.com/<yourusername>/PowerShell-Wsl-Manager Wsl-Manager
```

The source code of the module is located in the `Wsl-Manager.psm1` file. After a
modification, you need to ensure that the previous version is not loaded in
memory by unloading the module with:

```bash
❯ Remove-Module Wsl-Manager
❯
```

The loading of the new version is done automatically.

## Adding a new Exported cmdlet

To add a new cmdlet, you need to first create the function in
`Wsl-Manager.psm1`:

```powershell

function <approved_verb>-Wsl {
    <#
    .SYNOPSIS
    ...
    #>
    [CmdletBinding()]
    param(
        ...
    )
}
```

PowerShell is picky about cmdlet verbs. The list is available
[here](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.3).

Then at the end of the file, export the function:

```bash
Export-ModuleMember <approved_verb>-Wsl
```

You also need to add the cmdlet to the `FunctionsToExport` property of the
hashtable in the `Wsl-Manager.psd1` file:

```bash
    FunctionsToExport = @("Install-Wsl", "Remove-WslInsance", "Export-WslInstance", "Get-WslImage", "Get-WslInstance", "Invoke-WslInstance", "<approved_verb>-WslInstance")
```

Then by removing the module, you are able to test the cmdlet:

```bash
❯ Remove-Module Wsl-Manager
❯ <approved_verb>-WslInstance ...
```

[git]: https://git-scm.com/download/win
[scoop]: https://scoop.sh/
[vscode]: https://code.visualstudio.com/
