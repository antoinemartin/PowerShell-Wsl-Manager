# PowerShell-Wsl-Manager Development Guide

## Project Overview

PowerShell module for managing WSL **images** (root filesystems) and
**instances** (distributions). Think Hyper-V PowerShell cmdlets, but for WSL.
Uses SQLite to track image sources and local files, with pre-configured Linux
environments (oh-my-zsh, powerlevel10k, SSH/GPG integration).

**Architecture:** Three-layer module structure (Image/Instance/Common) + C#
SQLite wrapper + shell configuration scripts.

## Module Structure

```
Wsl-Common/      # Shared types & exceptions (WslManagerException hierarchy)
Wsl-ImageSource/ # Image source definitions (Docker, Incus, URI, Local)
Wsl-Image/       # Image management (fetchers, database, Docker/Incus sources)
Wsl-Instance/    # Distribution lifecycle (registry, wsl.exe wrapper)
Wsl-SQLite/      # C# SQLite helper + PowerShell wrapper
```

**Key files:**

- [Wsl-Manager.psd1](../Wsl-Manager.psd1): Module manifest (NestedModules load
  order matters!)
- [Wsl-Manager.psm1](../Wsl-Manager.psm1): Entry point, type accelerators, tab
  completion
- [configure.sh](../configure.sh): Bash script that configures instances (zsh,
  oh-my-zsh, powerlevel10k, non-root user...) in new instances
- [Wsl-Image/db.sqlite](../Wsl-Image/db.sqlite): SQLite schema seed file

## Type System & Classes

**PowerShell classes** (not C#) define core types:

- `WslImage`, `WslImageSource`, `WslInstance` - Main domain objects
- Enums: `WslImageType`, `WslImageState`, `WslInstanceState`,
  `WslImageSourceType` (Flags)
- Exception hierarchy: `WslManagerException` → `WslImageException` → specific
  errors
- Wsl-Image database access: `WslImageDatabase`

**Type accelerators** exported in
[Wsl-Manager.psm1](../Wsl-Manager.psm1#L40-L46) for convenience (`[WslInstance]`
vs `Microsoft.PowerShell.WslManager.WslInstance`).

**Formatting:** [Wsl-Manager.Format.ps1xml](../Wsl-Manager.Format.ps1xml)
defines table views. [Wsl-Manager.Types.ps1xml](../Wsl-Manager.Types.ps1xml)
adds computed properties (avoid bloating class definitions).

## SQLite Database

**Location:** `$env:LOCALAPPDATA\Wsl\RootFS\images.db` (Windows) or
`$HOME/.local/share/Wsl/RootFS/images.db` (Linux, tests only)

**Tables:**

- `ImageSource`: All known sources (Builtin/Incus/Docker/Uri/Local)
- `LocalImage`: Downloaded files on disk (state: Synced/Outdated/NotDownloaded)
- `ImageSourceCache`: ETags for builtin/remote catalogs

**Access pattern:**

1. `Get-WslImageDatabase` opens a singleton connection with 3-minute idle
   timeout
2. `WslImageDatabase` class wraps `SQLiteHelper` (C# type, see below)
3. All queries use parameterized SQL via `ExecuteSingleQuery`/`ExecuteNonQuery`

**C# SQLite Helper:**

- Pre-compiled to
  `Wsl-SQLite/bin/{net48,net8.0,net8.0-windows}/WslSQLiteHelper.dll`
- Fallback: runtime `Add-Type` compilation from
  [SQLiteHelper.cs](../Wsl-SQLite/SQLiteHelper.cs)
- Build: `pwsh -File ./Wsl-SQLite/Build-SQLiteHelper.ps1 -Configuration Release` (requires .NET SDK
  8.0+)

## Testing

**Framework:** Pester v5 with >85% code coverage target
([CodeCov](https://app.codecov.io/gh/antoinemartin/PowerShell-Wsl-Manager))

**Run tests:**

```powershell
# Quick (no coverage):
pwsh -File ./hack/Invoke-Tests.ps1
# With coverage:
pwsh -File ./hack/Invoke-Tests.ps1 -All
# Filter by test name:
pwsh -File ./hack/Invoke-Tests.ps1 -Filter "WslImage.Database*"
# VS Code task:
Run tests (Ctrl+Shift+P → Tasks: Run Task)
```

**Test utilities in `tests/`:**

- [TestUtils.psm1](../tests/TestUtils.psm1): Mocks, fixtures, `$MockBuiltins`
  data
- [TestRegistryMock.psm1](../tests/TestRegistryMock.psm1): In-memory registry
  for WSL tests
- [TestAssertions.psm1](../tests/TestAssertions.psm1): Custom Pester assertions
- `fixtures/`: Pre-recorded HTTP responses for offline testing

**Mocking pattern:**

```powershell
BeforeAll {
    Mock Invoke-WebRequest { /* fixture */ }
    $script:db = Get-WslImageDatabase
}
AfterAll { Close-WslImageDatabase }
```

**Test Module features:**

```powershell
  # Setup test environment
  $file = Get-Item -Path (Join-Path -Path $path -ChildPath $localTarFile)

  # Perform operation in module scope to access internal functions
  $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
      file = $file
  } -ScriptBlock {
      $image = Get-DistributionInformationFromFile -File $file -Verbose
      return $image
  }

  # Assertions (can also be done inside InModuleScope block)
  $image.Type | Should -Be "Local"
#

## Naming Conventions

**Functions:** Standard PowerShell verb-noun (`Get-WslImage`, `New-WslInstance`)

- Image cmdlets: `*-WslImage*` (sources: `*-WslImageSource`)
- Instance cmdlets: `*-WslInstance`, `Invoke-Wsl*`

**Internal functions:** No "Export" in manifest = private (helpers in
`*Helpers.ps1` files)

**Variables:** PascalCase for module-level, camelCase for local. Globals avoided
except `$ImageDatadir`, `$base_Image_directory`.

**Suppression attributes:** Use
`[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]` for intentional
PSScriptAnalyzer warnings.

## Code Quality

**Pre-commit hooks** (Python-based, run via `pipx`):

```bash
pre-commit run         # Run all hooks on staged files
pre-commit run --all   # Run on entire codebase
```

**Hooks:**

- PSScriptAnalyzer:
  [hack/Invoke-ScriptAnalyzer.ps1](../hack/Invoke-ScriptAnalyzer.ps1)
- cspell: Spell checker ([cspell.json](../cspell.json) config)
- General: trailing whitespace, CRLF normalization (except
  `.sh`/`.zsh`/`Dockerfile`)

**Coverage exclusions:** Add `# nocov` comment to lines or blocks (processed by
[hack/Invoke-Tests.ps1](../hack/Invoke-Tests.ps1#L18-L40)).

## Development Workflows

**Setup:**

```powershell
# Clone to module path for auto-loading
git clone <fork> "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\Wsl-Manager"
cd Wsl-Manager

# Install Python tools
scoop install python pipx uv
pipx install pre-commit

# Build SQLite helper (optional but recommended)
pwsh -File .\Wsl-SQLite\Build-SQLiteHelper.ps1 -Configuration Release -Clean
```

**Build documentation:**

```powershell
# Rebuild reference docs:
pwsh -File "./hack/Invoke-ReferenceDocumentationBuild.ps1" -ModuleName "Wsl-Manager" -DestinationDirectory "./docs/usage/reference"
# Build site:
uv run mkdocs build --clean --strict
# Serve locally:
uv run mkdocs serve
```

**Docker image management:**

- Images built via GitHub Actions
  (workflow [.github/workflows/build-rootfs-oci.yaml](../.github/workflows/build-rootfs-oci.yaml)
  for builtins,
  workflow [.github/workflows/build-incus-rootfs-list.yaml](../.github/workflows/build-incus-rootfs-list.yaml)
  for incus)
- Stored in GHCR (GitHub Container Registry) as single-layer OCI images
- Metadata for builtins and incus images generated in `rootfs` branch:
  - `builtins.rootfs.json`
  - `incus.rootfs.json`

## WSL Integration

**Registry access:**
[Wsl-Instance.Helpers.ps1](../Wsl-Instance/Wsl-Instance.Helpers.ps1) wraps
`HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss`

- `Get-WslRegistryKey`: Returns `WslRegistryKey` object (abstraction over
  registry)
- Mocked in tests via `TestRegistryMock.psm1`

**wsl.exe wrapper:** All WSL operations via `wsl.exe` commands (no P/Invoke)

- Instance creation: `wsl.exe --import <name> <path> <tarball>`
- Configuration: `wsl.exe --exec <name> <command>` runs
  [configure.sh](../configure.sh)

**File paths:**

- Images: `$env:LOCALAPPDATA\Wsl\RootFS\<hash>.rootfs.tar.gz`
- Instances: `$env:LOCALAPPDATA\Wsl\<InstanceName>\ext4.vhdx`

## Common Patterns

**Parameter validation:**

```powershell
[ValidateScript({ Test-Path $_ }, ErrorMessage = "File not found: {0}")]
[Parameter(Mandatory)]
[string]$Path
```

**Error handling:** Throw typed exceptions from `Wsl-Common.Types.ps1`:

```powershell
throw [WslImageException]::new("Image not found: $Name")
```

**ShouldProcess support:** All state-changing functions must support
`-WhatIf`/`-Confirm`:

```powershell
if ($PSCmdlet.ShouldProcess("Target", "Action")) { /* modify state */ }
```

**Verbose logging:** Extensive `Write-Verbose` for debugging (check
[Wsl-Image.Database.ps1](../Wsl-Image/Wsl-Image.Database.ps1) for examples).

## Gotchas

1. **Module loading order matters:** `NestedModules` in
   [Wsl-Manager.psd1](../Wsl-Manager.psd1#L69-L81) must load Types before
   Cmdlets
2. **SQLite connection pooling:** Always use `Get-WslImageDatabase` singleton
   (direct `New-WslImageDatabase` creates parallel connections!)
3. **Registry mocking:** Tests must import `TestRegistryMock.psm1` _before_ any
   Instance cmdlets
4. **Image file naming:** Hash-based filenames (`<SHA256>.rootfs.tar.gz`)
   prevent duplicates
5. **Cross-platform paths:** Use `[Path]::DirectorySeparatorChar`, not hardcoded
   `/` or `\`
6. **PowerShell 5.1 compatibility:** Module supports Desktop + Core; Tests run on
   Core only (Github Actions linux runners)

## Documentation

**Structure:**

- `docs/usage/`: User-facing guides (Create instances, manage images)
- `docs/development/`: Developer guide.
- `docs/examples/`: Docker integration, GPG/SSH setup examples

**Build system:** MkDocs with Material theme ([mkdocs.yml](../mkdocs.yml)),
published to GitHub Pages. Uses awesome navigation instead of directory listing.

**Reference docs:** Auto-generated from comment-based help via
[hack/Invoke-ReferenceDocumentationBuild.ps1](../hack/Invoke-ReferenceDocumentationBuild.ps1)
