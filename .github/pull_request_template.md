## Description

**What does this PR do?** Provide a clear and concise description of the changes
in this pull request.

**Related Issue(s)** Closes #(issue number) Fixes #(issue number) Relates to
#(issue number)

## Type of Change

Please check the relevant option(s):

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to
      not work as expected)
- [ ] Documentation update
- [ ] Code refactoring (no functional changes)
- [ ] Performance improvement
- [ ] Test coverage improvement
- [ ] CI/CD or build configuration change

## Changes Made

**Summary of changes:**

- Change 1
- Change 2
- Change 3

**Files modified (Optional):**

- `path/to/file1.ps1` - Description of changes
- `path/to/file2.ps1` - Description of changes

## Testing

**Test coverage:**

- [ ] Unit tests added/updated for all new/modified code
- [ ] All tests pass locally (`pwsh ./hack/Invoke-Tests.ps1 -All`)
- [ ] Code coverage is 100% for modified/new code (check `coverage.xml`)
- [ ] Used `# nocov` comments only where absolutely necessary with clear
      justification

**Manual testing performed:** Describe the manual testing you performed to
validate your changes.

```powershell
# Paste commands used for manual testing
```

**Test output:**

```
# Paste relevant test output or describe results
```

## Documentation

- [ ] Updated comment-based help for modified/new cmdlets
- [ ] Regenerated reference documentation
      (`pwsh -File "./hack/Invoke-ReferenceDocumentationBuild.ps1" -ModuleName "Wsl-Manager" -DestinationDirectory "./docs/usage/reference"`)
- [ ] Updated user-facing documentation in `docs/` if needed
- [ ] Added code comments for complex logic
- [ ] Updated CHANGELOG (if applicable)

## Code Quality

- [ ] All files added to git staging area
- [ ] Pre-commit checks passed (`pre-commit run`)
- [ ] `PSScriptAnalyzer` warnings addressed or suppressed with justification
- [ ] No spelling errors (cspell check passed)
- [ ] Follows project naming conventions and patterns (see
      [copilot-instructions.md](.github/copilot-instructions.md))

## Module Updates (if applicable)

- [ ] Updated `Wsl-Manager.psd1`:
  - [ ] Added new functions to `FunctionsToExport`
  - [ ] Added new aliases to `AliasesToExport`
  - [ ] Updated module version if needed
- [ ] Updated `Wsl-Manager.psm1`:
  - [ ] Added type accelerators for new types
  - [ ] Added tab completion for new cmdlets
  - [ ] Registered new aliases

## Database Changes (if applicable)

- ~~[ ] Updated SQLite schema in `Wsl-Image/db.sqlite`~~ **Please do not modify
  the database schema directly.** Use migration scripts instead.
- [ ] Incremented `[WslImageDatabase]::CurrentVersion`
- [ ] Added migration logic to `UpdateIfNeeded()` method
- [ ] Tested migration from previous version

## Breaking Changes

**Are there any breaking changes?**

- [ ] No breaking changes
- [ ] Yes, breaking changes (describe below)

**If yes, describe the breaking changes and migration path:**

```
Describe what breaks and how users should update their code/workflows.
```

## Additional Notes (Optional)

**Dependencies:** List any new dependencies or changes to existing dependencies.

**Screenshots/Output:** If applicable, add screenshots or command output showing
the new functionality.

**Performance Considerations:** Describe any performance implications of your
changes.

**Security Considerations:** Describe any security implications of your changes.

## Checklist

Before requesting review, ensure you have completed:

- [ ] Read and followed the [development guide](.github/copilot-instructions.md)
- [ ] Reviewed my own code for obvious errors and improvements
- [ ] Verified all acceptance criteria from the related issue are met
- [ ] Tested on both Windows PowerShell 5.1 and PowerShell 7+
- [ ] Ensured backward compatibility (or documented breaking changes)
- [ ] Provided clear commit messages following project conventions

## Reviewer Notes (Optional)

**Areas requiring special attention:** List any specific areas or aspects of the
code that reviewers should pay special attention to.

**Questions for reviewers:** List any questions or concerns you have about the
implementation.
