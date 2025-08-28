# Architectural Research Analysis

## Executive Summary

This analysis examines the PowerShell WSL Manager module architecture, revealing
a well-structured PowerShell module following modern .NET/PowerShell patterns
but with some architectural inconsistencies and areas for improvement as the
codebase transitions toward version 2.0.

---

## Core Analysis

### Tools, Frameworks & Design Patterns

#### **Primary Technologies**

-   **PowerShell 5.1+ / PowerShell Core**: Cross-platform scripting with .NET
    integration
-   **PowerShell Classes**: Object-oriented design with custom types
    (`WslInstance`, `WslImage`, `WslImageHash`)
-   **PowerShell Enums**: Strong typing for state management
    (`WslInstanceState`, `WslImageType`, `WslImageSource`)
-   **Windows Registry APIs**: Direct Windows registry manipulation via
    `Microsoft.Win32.Registry`
-   **Docker Registry API**: HTTP-based container image management
-   **Web APIs**: REST calls to Incus/LXD image repositories

#### **Design Patterns Identified**

1. **Factory Pattern**: `WslImage` constructor overloading for different
   initialization methods
2. **Command Pattern**: PowerShell cmdlets following verb-noun conventions
3. **Wrapper Pattern**: `Wrap-Wsl` and `Wrap-Wsl-Raw` functions encapsulating
   wsl.exe calls
4. **Repository Pattern**: Image management with local caching and remote
   synchronization
5. **Strategy Pattern**: Multiple image source handling (Docker, Incus, Local,
   URI)

#### **PowerShell Best Practices**

-   **Advanced Functions**: Proper use of `[CmdletBinding()]` and parameter
    validation
-   **Pipeline Support**: `ValueFromPipeline` and
    `ValueFromPipelineByPropertyName` attributes
-   **Type Extensions**: Custom `.ps1xml` files for object formatting and
    properties
-   **Argument Completion**: Custom tab completion for distribution names
-   **Type Accelerators**: Custom type shortcuts for improved usability

### Data Models & API Design

#### **Core Domain Objects**

```powershell
# Primary entity representing WSL distributions
class WslInstance {
    [string]$Name
    [WslInstanceState]$State
    [int]$Version
    [bool]$Default
    [Guid]$Guid
    [int]$DefaultUid
    [FileSystemInfo]$BasePath
}

# Represents filesystem images for WSL
class WslImage {
    [WslImageType]$Type
    [WslImageState]$State
    [System.Uri]$Url
    [string]$LocalFileName
    [string]$Os
    [string]$Release
    [bool]$Configured
}
```

#### **API Design Patterns**

-   **Consistent Verb-Noun Naming**: `Get-WslInstance`, `New-WslInstance`,
    `Remove-WslInstance`
-   **Multiple Parameter Sets**: Different ways to invoke same functionality
-   **Pipeline Integration**: Objects flow naturally through cmdlet chains
-   **Rich Object Return Types**: Custom types with calculated properties

#### **Versioning Strategy**

-   **Module Manifest**: Version defined in `Wsl-Manager.psd1` (currently 1.0.0,
    targeting 2.0.0)
-   **Semantic Versioning**: Following SemVer patterns
-   **Backward Compatibility**: Aliases maintained for older function names

### Architectural Inconsistencies

#### **🔴 Critical Issues**

1. **Duplicate Type Definitions**

    ```powershell
    # DUPLICATE: WslImageState defined in TWO files
    # File 1: Wsl-Manager.psm1 (lines 717-721)
    # File 2: Wsl-RootFS\Wsl-RootFS.Types.ps1 (lines 13-17)
    ```

    **Impact**: PowerShell class loading conflicts, potential runtime errors
    **Root Cause**: Modular refactoring incomplete

2. **Exception Class Duplication**

    ```powershell
    # DUPLICATE: UnknownDistributionException in TWO files
    # File 1: Wsl-Manager.psm1 (line 23)
    # File 2: Wsl-RootFS\Wsl-RootFS.Types.ps1 (line 34)
    ```

3. **Inconsistent Error Handling Patterns**

    ```powershell
    # Pattern A: Custom exceptions with structured messages
    throw [DistributionAlreadyExistsException]$NewName

    # Pattern B: String-based error messages
    throw "wsl.exe failed: $output"

    # Pattern C: Generic exceptions
    throw "Configuration failed"
    ```

#### **🟡 Moderate Issues**

4. **Mixed State Management Approaches**

    - Registry-based persistence for some properties (`DefaultUid`, `BasePath`)
    - In-memory state for others (`State`, `Version`)
    - File-based metadata for images (`.json` files)

5. **Inconsistent Logging/Output Patterns**

    ```powershell
    # Multiple output approaches:
    Write-Verbose    # Standard PowerShell verbose
    | Write-Verbose  # Piped verbose output
    Progress         # Custom progress function
    Success          # Custom success function
    Information      # Custom info function
    ```

6. **Testing Architecture Gaps**
    - Mock classes (`MockRegistryKey`, `MockBaseKey`) mixed with production code
    - Some functions lack comprehensive test coverage
    - Test isolation concerns with global state

---

## Legacy Assessment

### Conflicting Architectural Patterns

#### **Legacy Pattern: Monolithic Module Structure**

```powershell
# OLD: Single large file (Wsl-Manager.psm1) - 1143 lines
# Contains: Classes, functions, cmdlets, enums all mixed together
```

#### **Modern Pattern: Modular Architecture**

```powershell
# NEW: Separated into logical modules
Wsl-RootFS\
├── Wsl-RootFS.Types.ps1      # Type definitions
├── Wsl-RootFS.Helpers.ps1    # Utility functions
├── Wsl-RootFS.Cmdlets.ps1    # Public cmdlets
├── Wsl-RootFS.Docker.ps1     # Docker integration
└── Wsl-RootFS.Builtins.ps1   # Built-in distributions
```

### Evolution Timeline Analysis

#### **Version 1.0 Architecture** (Legacy)

-   Single monolithic `.psm1` file
-   Basic WSL wrapper functionality
-   Simple cmdlet structure
-   Limited error handling

#### **Version 2.0 Architecture** (Target)

-   Modular file organization
-   Rich type system with classes/enums
-   Multiple image sources (Docker, Incus, Local)
-   Enhanced error handling with custom exceptions
-   Comprehensive testing framework

### Recommended Migration Path

#### **Phase 1: Type System Consolidation** (High Priority)

```powershell
# CONSOLIDATE: Move all shared types to single location
# Recommended: Wsl-RootFS\Wsl-RootFS.Types.ps1
# Remove duplicates from: Wsl-Manager.psm1
```

**External Reference**:
[PowerShell Classes Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/ps101/09-functions?view=powershell-7.3)

#### **Phase 2: Error Handling Standardization**

```powershell
# STANDARDIZE: Consistent exception hierarchy
class WslManagerException : System.SystemException { }
class UnknownDistributionException : WslManagerException { }
class DistributionAlreadyExistsException : WslManagerException { }
```

**External Reference**:
[PowerShell Error Handling Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions)

#### **Phase 3: State Management Unification**

-   **Current Issues**: Registry, files, and memory state scattered
-   **Recommendation**: Implement centralized state management pattern
-   **External Reference**:
    [Repository Pattern in PowerShell](https://devblogs.microsoft.com/powershell/powershell-and-design-patterns/)

#### **Phase 4: Testing Architecture Improvement**

-   **Separate**: Test utilities from production code
-   **Implement**: Dependency injection for external dependencies (Registry,
    WSL.exe)
-   **External Reference**:
    [Pester Testing Best Practices](https://pester.dev/docs/quick-start)

---

## Architectural Debt Summary

### **High Impact Issues** (Fix Immediately)

1. **Duplicate type definitions** - Runtime conflicts possible
2. **Exception class duplication** - Inconsistent error handling
3. **Mixed error handling patterns** - Poor user experience

### **Medium Impact Issues** (Plan for v2.0)

4. **State management inconsistencies** - Maintenance complexity
5. **Output/logging pattern variations** - Inconsistent diagnostics
6. **Test architecture gaps** - Reduced reliability

### **Low Impact Issues** (Technical debt)

7. **Large monolithic main file** - Reduced maintainability
8. **Missing comprehensive documentation** - Developer onboarding
9. **Hard-coded paths and constants** - Deployment flexibility

---

## Recommendations Priority Matrix

| Priority | Issue                           | Effort | Impact | Timeline |
| -------- | ------------------------------- | ------ | ------ | -------- |
| **P0**   | Type definition deduplication   | Medium | High   | Sprint 1 |
| **P0**   | Exception standardization       | Low    | High   | Sprint 1 |
| **P1**   | Error handling consistency      | Medium | High   | Sprint 2 |
| **P1**   | State management unification    | High   | Medium | Sprint 3 |
| **P2**   | Testing architecture separation | Medium | Medium | Sprint 4 |
| **P2**   | Logging standardization         | Low    | Low    | Sprint 4 |

---

## External Best Practice References

1. **PowerShell Module Design**:
   [Microsoft PowerShell Module Guidelines](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-windows-powershell-module)
2. **PowerShell Classes**:
   [About PowerShell Classes](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes)
3. **Error Handling**:
   [PowerShell Exception Handling](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions)
4. **Testing**:
   [Pester Framework Documentation](https://pester.dev/docs/quick-start)
5. **Repository Pattern**:
   [PowerShell Design Patterns](https://devblogs.microsoft.com/powershell/powershell-and-design-patterns/)

---

_This analysis identifies critical architectural inconsistencies that should be
addressed before the 2.0 release to ensure maintainability and reliability of
the WSL Manager PowerShell module._
