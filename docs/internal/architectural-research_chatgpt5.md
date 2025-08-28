# Architectural Research — PowerShell-Wsl-Manager

Date: 2025-08-20 Branch analyzed: 29-refactorings-toward-version-20 Scope:
PowerShell module (`Wsl-Manager`) + nested `Wsl-RootFS` components, tests, and
docs config

## CORE ANALYSIS

### Tools, frameworks, and patterns used

-   PowerShell module structure
    -   Manifest: `Wsl-Manager.psd1` with `RootModule`, `NestedModules`,
        `TypesToProcess`, `FormatsToProcess`, and broad exports.
    -   Public cmdlets defined in `Wsl-Manager.psm1`; nested modules under
        `Wsl-RootFS/*.ps1` for types/helpers/networking.
    -   Aliases and ArgumentCompleters registered in `Wsl-Manager.psm1`.
-   Testing and docs
    -   Pester tests: `Wsl-Manager.Tests.ps1` (+ `Wsl-RootFS.Tests.ps1`
        present).
    -   MkDocs Material documentation (`mkdocs.yml`, `docs/**`).
-   Networking and downloads
    -   Custom downloader `download.ps1` adapted from Scoop
        (WebRequest/WebClient, manual redirects, progress UI).
    -   OCI/registry integration for GHCR: `Wsl-RootFS.Docker.ps1` uses token
        exchange + manifest negotiation.
-   Domain model (PowerShell classes)
    -   `WslInstance` (WSL distro), `WslImage` (rootfs image), `WslImageHash` (+
        enums), `WslImageSource [Flags]`.
    -   Sidecar metadata JSON for images: `*.rootfs.tar.gz.json`.
-   Patterns observed
    -   Facade/Adapter over native `wsl.exe` (`Wrap-Wsl`, `Wrap-Wsl-Raw`).
    -   Repository-style lookup for images (`WslImage::LocalFileSystems`, remote
        catalogs via `Get-WslBuiltinImage`).
    -   Value Objects for hashes and metadata; in-memory cache keyed by URL for
        hash sources.

### Data models + API design & versioning

-   Data models
    -   `WslInstance` properties: Name, State, Version, Default, Guid,
        DefaultUid, BasePath; registry-driven enrichment.
    -   `WslImage` properties: Name, Os, Release, Type, State, Url, Configured,
        Username, Uid, LocalFileName, FileHash.
    -   Sidecar JSON mirrors `WslImage.ToObject()`; used to derive metadata when
        file exists locally.
-   Public API surface (selected)
    -   Instance lifecycle: `New-WslInstance`, `Remove-WslInstance`,
        `Stop-WslInstance`, `Rename-WslInstance`, `Set-WslDefaultUid`,
        `Set-WslDefaultInstance`, `Invoke-WslInstance`, `Invoke-WslConfigure`.
    -   Image lifecycle: `New-WslImage`, `Get-WslImage`, `Sync-WslImage`,
        `Remove-WslImage`, `Get-IncusImage`, `Export-WslInstance`.
-   Versioning
    -   Manifest `ModuleVersion = 1.0.0` yet branch/ref docs indicate features
        suitable for a 2.x refactor. No explicit API versioning or deprecation
        policy in code.

### Architectural inconsistencies / deviations

Prioritized by impact to correctness, maintainability, and user experience:

1. Duplicate type definitions across modules [High]

-   ~~Evidence: `Wsl-Manager.psm1` defines `WslImageType`, `WslImageState`;
    `Wsl-RootFS.Types.ps1` defines the same enums and also
    `UnknownDistributionException` appears in both files.~~
-   Risk: Class/enum re-definition can fail module import and breaks
    single-source-of-truth. A FIXME comment already acknowledges sharing
    problems.
-   File refs: `Wsl-Manager.psm1` (around “FIXME: Enumerations…”),
    `Wsl-RootFS.Types.ps1` (top section).

2. Logging via Write-Host instead of channel-aware streams [High]

-   Evidence: `Progress`, `Success`, `Information` in `Wsl-RootFS.Helpers.ps1`
    use `Write-Host` (with emoji prefixes) and are widely used across commands.
-   Impact: `Write-Host` bypasses streams, complicates automation, redirection,
    and CI logs. Best practice is `Write-Verbose`, `Write-Information`, and
    `Write-Progress` with `-Verbose`/`$InformationPreference` support.

3. Manifest exports and scope pollution [High]

-   ~~Evidence: `VariablesToExport = '*'` in `Wsl-Manager.psd1` exports all
    variables.~~
-   Impact: Pollutes caller scope; increases risk of collisions/unintended side
    effects; violates least-privilege export.

4. ~~Non-approved verb and naming inconsistencies [Medium]~~

-   Evidence: `Sync-WslImage` uses verb “Sync” (not approved).
    `Invoke-WslConfigure` performs configuration rather than an “invoke” action.
    Comments reference legacy `Remove-WslInstance`.
-   Impact: Discoverability and consistency with PowerShell ecosystem reduced;
    tab completion/docs expectations mismatch.

5. Mixed HTTP stacks and legacy APIs [Medium]

-   Evidence: Uses `WebClient`, raw `HttpWebRequest`, and `Invoke-WebRequest`
    across files; manual header management and redirects.
-   Impact: Inconsistent behavior, harder testing; `WebClient` is legacy in
    modern .NET—prefer `Invoke-RestMethod` or `System.Net.Http.HttpClient`.

6. Potentially invalid/ineffective parameter attribute [Medium]

-   Evidence: `[SupportsWildcards()]` is used as a parameter attribute in
    multiple cmdlets.
-   Impact: This attribute doesn’t exist as a PowerShell parameter attribute
    (wildcards are convention + help metadata). It may be ignored, giving a
    false sense of validation.

7. ~~Error handling patterns inconsistent [Medium]~~

-   Evidence: Both custom exceptions and string throws (e.g.,
    `throw "Configuration failed"`); `Wrap-Wsl` sets `$hasError` after a `throw`
    (unreachable).
-   Impact: Inconsistent error records and limited context for callers; hinders
    robust `try/catch` and `$ErrorActionPreference` usage.

8. ~~External tool dependency for TAR extraction [Medium]~~

-   Evidence: `tar -xOf` used to read `os-release` from `*.tar.gz` in
    `Wsl-RootFS.Types.ps1`.
-   Impact: Relies on presence/behavior of external `tar` (bsdtar on Windows);
    portability and error handling concerns.

9. Global/static caches without invalidation strategy [Low]

-   Evidence: `WslImage.HashSources` and builtin lists cache; some invalidation
    exists (ETag/time), others rely on process lifetime.
-   Impact: Edge cases on long-running sessions; testing complexity.

10. UI/UX coupling in core logic [Low]

-   Evidence: Emoji-in-logging and manual console width handling in
    `download.ps1`.
-   Impact: Nice UX interactively, but hinders non-interactive runs and
    structured logs.

## LEGACY ASSESSMENT

-   Conflicting/multiple architectural patterns

    -   Types/enums duplicated between root module and nested types module
        (attempt to work around module scoping of classes).
    -   Mixed HTTP layers (custom WebRequest/WebClient/Invoke-WebRequest) +
        custom downloader adapted from Scoop.
    -   Command naming lineage: legacy references to `Remove-WslInstance` in
        comments; present-day cmdlet is `Remove-WslInstance`.

-   Distinguishing old vs new approaches

    -   Old: duplicated enums/classes, `Write-Host`-centric progress, legacy
        `WebClient` usage, ad-hoc tar parsing, non-approved verbs.
    -   New(er): Structured domain classes for images/instances, ETag-aware
        caching for builtins, proper `SupportsShouldProcess`, argument
        completers, sidecar JSON metadata for idempotency.

-   Recommended path forward (with sources)
    1. Single source for types and enums; load order guarantees
        - Consolidate `WslImageType`, `WslImageState`,
          `UnknownDistributionException` into `Wsl-RootFS.Types.ps1` (or a new
          `Wsl-Types.ps1`) and remove duplicates from `Wsl-Manager.psm1`.
        - Export classes via `using module` or a dedicated “types” nested
          module; avoid redefining.
        - Reference: PowerShell classes in modules, module manifests, and type
          exporting
            - About Module Manifests:
              https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_Module_Manifests
    2. Adopt stream-friendly logging
        - Replace `Write-Host` calls in `Progress/Success/Information` with
          `Write-Verbose`, `Write-Information`, and `Write-Progress`; keep emoji
          as optional formatting behind a switch.
        - Plumb `-Verbose` and `$PSCmdlet.ShouldProcess()` consistently.
        - References: Write-Verbose, Write-Information
            - https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/write-verbose
            - https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/write-information
    3. Tighten manifest exports and metadata
        - Set `VariablesToExport = @()` and explicitly export only required
          functions/aliases.
        - Consider `CompatiblePSEditions`, `PowerShellVersion`, and accurate
          `ModuleVersion` for the upcoming 2.0.
        - Reference: Module manifest best practices
            - https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_Module_Manifests
    4. Align cmdlet verbs with approved list; deprecation plan
        - Rename `Sync-WslImage` → `Update-WslImage` (keep alias `Sync-WslImage`
          with `[Obsolete]`-style warning in help for one major version).
        - Consider `Initialize-WslInstance` for `Invoke-WslConfigure`.
        - Approved verbs:
          https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-verbs
    5. Standardize HTTP access
        - Prefer `Invoke-RestMethod` for JSON APIs; create a small abstraction
          to set headers and handle retries, ETag, and timeouts.
        - Avoid `WebClient`; where streaming is needed, use
          `System.Net.Http.HttpClient` with
          `HttpCompletionOption.ResponseHeadersRead`.
        - Reference: .NET WebClient guidance (prefer HttpClient)
            - https://learn.microsoft.com/dotnet/api/system.net.webclient (see
              remarks)
    6. Replace/guard external tar dependency
        - Prefer native parsing where feasible. For TAR GZ, evaluate
          `System.Formats.Tar` (on .NET 7+) via PowerShell 7+ or keep the
          existing `tar` approach but add capability checks and clearer errors.
        - Reference: System.Formats.Tar
            - https://learn.microsoft.com/dotnet/api/system.formats.tar
    7. Parameter metadata correctness
        - Remove `[SupportsWildcards()]` attributes; document wildcard support
          in help and validate patterns via `-like`/`-match` or
          `[ValidatePattern()]` where applicable.
        - Reference: Cmdlet design guidelines for parameters
            - https://learn.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-overview
    8. Error handling consistency
        - Prefer throwing `ErrorRecord` or custom exception types with
          meaningful `CategoryInfo`; avoid bare string throws.
        - Fix unreachable code in `Wrap-Wsl` and centralize exit-code handling
          for native calls; emit errors via `Write-Error` when appropriate with
          `-ErrorAction` support.
        - Reference: ShouldProcess and error semantics
            - https://learn.microsoft.com/powershell/scripting/developer/cmdlet/shouldprocess
    9. CI and analyzers
        - Add PSScriptAnalyzer to CI for style and best practices enforcement.
        - Ensure Pester covers Docker path, Incus listing, and failure modes
          (auth, 404, hash mismatch).
        - References:
            - PSScriptAnalyzer: https://github.com/PowerShell/PSScriptAnalyzer
            - Pester: https://pester.dev/

## Examples from codebase (selected)

-   Duplicated enums and exception
    -   `Wsl-Manager.psm1`: defines `WslImageType`, `WslImageState`,
        `UnknownDistributionException`.
    -   `Wsl-RootFS.Types.ps1`: defines same names; plus a distinct
        `UnknownIncusDistributionException`.
-   Write-Host based logging
    -   `Wsl-RootFS.Helpers.ps1` functions `Progress`, `Success`, `Information`
        invoked across cmdlets (`New-WslInstance`, `Export-WslInstance`, etc.).
-   Non-approved verb
    -   `Sync-WslImage` in `Wsl-RootFS.Cmdlets.ps1`.
-   Mixed HTTP APIs
    -   `download.ps1` (WebRequest/WebClient), `Wsl-RootFS.Docker.ps1`
        (WebClient + Invoke-WebRequest), `Get-WslBuiltinImage`
        (Invoke-WebRequest with ETag), `Sync-String` (WebClient).
-   Manifest export breadth
    -   `Wsl-Manager.psd1`: `VariablesToExport = '*'`.
-   Error handling
    -   `Wrap-Wsl` throws then sets `$hasError = $true` (unreachable). Several
        `throw "Configuration failed"` without context.

## Recommended roadmap (impact → effort)

1. ~~Single-source types (High → Low/Med)~~

-   Move all enums/classes into `Wsl-RootFS.Types.ps1` (or `Wsl-Types.ps1`).
    Remove duplicates from `Wsl-Manager.psm1`. Add unit test ensuring module
    import doesn’t attempt redefinition.

2. Logging refactor (High → Med)

-   Rework `Progress/Success/Information` to stream-aware logging; add
    `-Verbose` surfaces. Provide a `-UseEmoji` preference variable to keep the
    current UX optionally.

3. ~~Manifest hygiene (High → Low)~~

-   Set `VariablesToExport = @()`. Consider explicitly listing
    `FunctionsToExport` rather than wide set. Add
    `PowerShellVersion`/`CompatiblePSEditions`.

4. Rename and deprecate (Med → Med)

-   Introduce `Update-WslImage` and `Initialize-WslInstance` with aliases from
    old names; mark legacy names in help. Document compatibility policy.

5. HTTP unification (Med → Med)

-   Introduce `Invoke-HttpJson`/`Start-HttpDownload` helpers with retries,
    headers, ETag, and timeouts. Replace `WebClient` call sites.

6. TAR handling (Med → Med)

-   Add capability check for `tar`; if unavailable, fail with actionable
    guidance or use `System.Formats.Tar` when available.

7. Error consistency (Med → Low)

-   Normalize throwing patterns; fix `Wrap-Wsl` flow; return rich
    `ErrorRecord`s.

8. CI quality gates (Med → Low)

-   ~~Add PSScriptAnalyzer~~, expand Pester coverage, and a smoke test that
    imports the module and lists instances/images.

## References

-   Approved verbs for PowerShell cmdlets:
    https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-verbs
-   ShouldProcess and ConfirmImpact:
    https://learn.microsoft.com/powershell/scripting/developer/cmdlet/shouldprocess
-   About module manifests:
    https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_Module_Manifests
-   Write-Verbose (logging best practices):
    https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/write-verbose
-   Write-Information:
    https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/write-information
-   .NET WebClient (prefer HttpClient):
    https://learn.microsoft.com/dotnet/api/system.net.webclient
-   System.Formats.Tar:
    https://learn.microsoft.com/dotnet/api/system.formats.tar
-   PSScriptAnalyzer: https://github.com/PowerShell/PSScriptAnalyzer
-   Pester testing framework: https://pester.dev/

## Summary

-   Primary architectural debt: duplicated type definitions, logging via
    Write-Host, broad manifest exports, and mixed HTTP stacks.
-   The module’s domain model and idempotent image metadata sidecars are strong
    foundations. A small, targeted refactor (types centralization,
    logging/manifest hygiene, and HTTP abstraction) will significantly improve
    maintainability, automation-friendliness, and alignment with PowerShell best
    practices.
