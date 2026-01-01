---
name: Bug report
about: Create a report to help us improve
title: "[BUG] "
labels: bug
assignees: ""
---

## Bug Description

**Describe the bug**

A clear and concise description of what the bug is.

**Expected behavior**

A clear and concise description of what you expected to happen.

**Actual behavior**

A clear and concise description of what actually happened.

## Reproduction Steps

**Steps to reproduce the behavior:**

1. Run command '...'
2. Use parameters '...'
3. See error

**Minimal reproducible example:**

```powershell
# Paste your PowerShell commands here
```

## Environment

**System Information:**

- OS: [e.g., Windows 11 23H2]
- PowerShell Version: [e.g., 7.4.1 or 5.1.22621.4111]
- Wsl-Manager Version: [e.g., 2.0.0]
- WSL Version: [run `wsl --version` or `wsl -v`]

**Additional context:**

Add any other context about the problem here (logs, screenshots, etc.).

## Pre-Submission Checklist

Before submitting this issue, please verify:

- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have included all relevant information above
- [ ] I have provided a minimal reproducible example if applicable
- [ ] I have checked the
      [documentation](https://antoinemartin.github.io/PowerShell-Wsl-Manager/)
      for solutions

## For Contributors

If you plan to fix this bug, please ensure:

### Documentation Generation

When a cmdlet is created or modified, update the documentation comment in the
source file, then regenerate documentation:

```powershell
pwsh -File "./hack/Invoke-ReferenceDocumentationBuild.ps1" -ModuleName "Wsl-Manager" -DestinationDirectory "./docs/usage/reference"
```

### Tests

Unit tests should be added to cover the modified code in `tests/*.Tests.ps1`. If
several tests are added, create a separate Pester context.

Run tests with:

```powershell
pwsh ./hack/Invoke-Tests.ps1 -Filter 'MainDescribe.SubContext.*'
```

**Target: 100% code coverage for modified/added code**

### Pre-commit Checks

Before submitting, add modified files to staging and run:

```powershell
pre-commit run
```

All checks must pass before submission.
