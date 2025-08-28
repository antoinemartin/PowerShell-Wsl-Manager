## Pre-requisites

To modify the module, you will need [git]. You can use [scoop] to install it.
Scoop will also allow you to install [vscode] that is the preferred development
environment.

In order to run `pre-commit` and build the documentation, you will need `python`
`pipx` and `uv` installed. This can be done easily with scoop:

```ps1con
PS> scoop install python pipx uv
```

Then you can install the pre-commit using `pipx`:

```ps1con
PS> pipx ensurepath
PS> pipx install pre-commit
```

## Getting started

To modify the module, first fork it on github and in clone your copy in your
local modules directory:

```ps1con
PS> New-Item -Path $env:USERPROFILE\Documents\WindowsPowerShell\Modules -Force | Out-Null
PS> cd $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
PS> git clone https://github.com/<yourusername>/PowerShell-Wsl-Manager Wsl-Manager
```

Having it in `$env:USERPROFILE\Documents\WindowsPowerShell\Modules\` ensures
that the module is loaded from the correct location when you import it in your
PowerShell session.

Another option (not recommended) is to add the directory where the module source
code has been cloned to `$env:PSModulePath`:

```ps1con
PS> $env:PSModulePath = (Get-Item -Path .).Parent.FullName + [System.IO.Path]::PathSeparator + $env:PSModulePath
```

However, this approach is not recommended as it can lead to confusion about the
module's location and make it harder to manage dependencies.

The source code of the module is organized as follows (only the relevant
files/directories are shown):

```bash
.
|-- .editorconfig                           # Editor configuration
|-- .github/                                # GitHub configuration (GHA workflows)
|-- .pre-commit-config.yaml                 # Pre-commit hooks configuration
|-- .prettierrc                             # Prettier configuration
|-- .python-version                         # Python version
|-- .vscode/                                # Visual Studio settings and launch configurations
|-- Dockerfile                              # Sample image Dockerfile
|-- Wsl-Common/                             # Common PowerShell code
|-- Wsl-Image/                              # Image management PowerShell code
|-- Wsl-Instance/                           # Instance management PowerShell code
|-- Wsl-Manager.Format.ps1xml               # [WslImage] and [WslInstance] formatting rules
|-- Wsl-Manager.Types.ps1xml                # Classes computed properties
|-- Wsl-Manager.psd1                        # Module definition
|-- Wsl-Manager.psm1                        # Main Module file
|-- configure.sh                            # Instance configuration script
|-- docs/                                   # Module documentation
|-- hack/                                   # Additional code
|-- mkdocs.yml                              # Documentation configuration (mkdocs)
|-- p10k.zsh                                # Powerlevel10k configuration
|-- pyproject.toml                          # Python project configuration (mkdocs)
|-- tests                                   # Unit tests
`-- uv.lock
```

The source code of the module is located in `Wsl-Common`, `Wsl-Image`, and
`Wsl-Instance` directories, as well as in the `Wsl-Manager.psm1` file. After a
modification, you need to ensure that the new version is loaded into memory
with:

```ps1con
PS> Import-Module Wsl-Manager -Force
```

!!! Warning "No unloading of Classes"

    Class definitions are not unloaded when the module is reloaded (see [powershell
    documentation][class unloading]). This means that if you modify a class
    definition, you need to close and re-create your Powershell session.

## Adding a new Exported cmdlet

To add a new cmdlet, you need to first create the function in
`Wsl-Image\Wsl-Image.Cmdlets.ps1` or `Wsl-Instance\Wsl-Instance.Cmdlets.ps1` :

```powershell

function <approved_verb>-Wsl... {
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

We prefer to put the documentation after the `function` declaration and before
the parameters declaration.

!!! note "About Cmdlet Verbs"

    PowerShell is picky about cmdlet verbs. The list of approved verbs is available
    [here](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.3).

Then export the function by adding it to the `FunctionsToExport` array of the
`Wsl-Manager.psd1` file:

```powershell
# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @("New-WslInstance", ..., "<approved_verb>-Wsl...")
```

We encourage you to create aliases for your cmdlets to make them easier to use.
Add your aliases at the end of `Wsl-Manager.psm1`:

```powershell
Set-Alias -Name <alias> -Value <approved_verb>-Wsl... -Force
```

And add them to the `AliasesToExport` array in the `Wsl-Manager.psd1` file:

```powershell
# Aliases to export from this module
AliasesToExport = @("<alias>","<alias>")
```

Then by removing the module, you are able to test the cmdlet:

```bash
❯ Remove-Module Wsl-Manager
❯ <approved_verb>-WslInstance ...
```

## Adding a new Object class

To add a new Object class, create a directory named after the name of the class,
`Wsl-<Something>`. Inside this directory, split the code into several files.
Let's look at the `Wsl-Instance` directory:

```bash
./Wsl-Instance/
|-- Wsl-Instance.Cmdlets.ps1           # Cmdlets operating on WslInstance objects
|-- Wsl-Instance.Helpers.ps1           # Helper functions for WslInstance objects
`-- Wsl-Instance.Types.ps1             # Type definitions for WslInstance objects
```

Once the code created and tested (see [testing](testing.md)), add the new files
to the `Wsl-Manager.psd1` file in `NestedModules` and `FileList`:

```powershell
  NestedModules     = @(
      'Wsl-Common\Wsl-Common.Types.ps1',
      'Wsl-Common\Wsl-Common.Helpers.ps1',
      ...
      # Add your files here
  )
...
  FileList          = @(
      "p10k.zsh",
      ...
      # Add your files here
  )
```

## Building the documentation

The documentation is built using `mkdocs`. You can build and serve the
documentation locally by running:

```ps1con
PS> uv run mkdocs serve
```

When you modify the documentation, the changes are automatically refreshed in
your browser.

!!! warning "About documentation auto-update"

    On windows, the refresh of the documentation after a modification is quite
    slow. It's much more convenient to update the documentation inside a WSL
    instance :smile:.

    :eyes: However, don't use the source code cloned on a Windows directory,
    but instead re-clone the project under WSL.

The final documentation can be built with:

```ps1con
PS> uv run mkdocs build --clean --strict
```

## Pre-commit routine

Before committing your changes, ensure that you have:

- **Updated the documentation** (see above)
- **Write the appropriate tests** in order to test the new features and stay
  above 85% of code coverage.
- **Run all tests** with the following command:

  ```ps1con
  PS> .\hack\Invoke-Tests.ps1 -All
  ```

- **Updated the cmdlets reference documentation** with the following command:

  ```ps1con
  PS> .\hack\Invoke-ReferenceDocumentationBuild.ps1 -ModuleName "Wsl-Manager" -DestinationDirectory ".\docs\usage\reference"
  ```

- **Check for typos / linting errors** by running `pre-commit`:

  ```ps1con
  PS> pre-commit run
  ```

<!-- prettier-ignore-start -->
[git]: https://git-scm.com/download/win
[scoop]: https://scoop.sh/
[vscode]: https://code.visualstudio.com/
[class unloading]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes?view=powershell-7.5#loading-newly-changed-code-during-development

<!-- prettier-ignore-end -->
