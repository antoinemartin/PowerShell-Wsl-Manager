---
name: Feature request
about: Suggest an idea or enhancement for this project
title: "[FEATURE] "
labels: enhancement
assignees: ""
---

## Feature Summary

**Is your feature request related to a problem? Please describe.**

A clear and concise description of what the problem is. Ex. I'm always
frustrated when [...]

**Describe the solution you'd like**

A clear and concise description of what you want to happen.

## Motivation and Use Case

**Why is this feature valuable?**

Explain the benefits and use cases for this feature.

**Who would benefit from this feature?**

Describe the target users (e.g., developers, system administrators, all users).

## Proposed Implementation

**How would you like this to work?**

Provide examples of commands, workflows, or UI changes.

```powershell
# Example of how the feature might be used
New-WslInstance -Name example -Feature NewParameter
```

**Are there alternative solutions you've considered?**

Describe any alternative solutions or features you've considered.

**Would you be willing to contribute this feature?**

Let us know if you'd like to implement this feature yourself.

## Additional Context

Add any other context, screenshots, mockups, or examples about the feature
request here.

**Related issues or discussions:**

Link to any related issues, pull requests, or discussions.

## Pre-Submission Checklist

Before submitting this feature request, please verify:

- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have clearly described the problem and proposed solution
- [ ] I have considered how this fits with the project's goals
- [ ] I have checked the
      [documentation](https://antoinemartin.github.io/PowerShell-Wsl-Manager/)
      to ensure this doesn't already exist

## For Contributors

If you plan to implement this feature, please ensure:

### Documentation Generation

When a cmdlet is created or modified, update the documentation comment in the
source file, then regenerate documentation:

```powershell
pwsh -File "./hack/Invoke-ReferenceDocumentationBuild.ps1" -ModuleName "Wsl-Manager" -DestinationDirectory "./docs/usage/reference"
```

### Tests

Unit tests should be added to cover the new code in `tests/*.Tests.ps1`. If
several tests are added, create a separate Pester context.

Run tests with:

```powershell
pwsh ./hack/Invoke-Tests.ps1 -Filter 'MainDescribe.SubContext.*'
```

**Target: 100% code coverage for new code**

### Pre-commit Checks

Before submitting, add modified files to staging and run:

```powershell
pre-commit run
```

All checks must pass before submission.

### Module Manifest

If adding new cmdlets, update:

- [Wsl-Manager.psd1](../../Wsl-Manager.psd1) - Add to `FunctionsToExport` and
  `AliasesToExport`
- [Wsl-Manager.psm1](../../Wsl-Manager.psm1) - Add aliases and tab completion if
  needed
