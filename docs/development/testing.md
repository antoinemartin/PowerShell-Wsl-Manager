# Testing

This document explains how to write and execute tests for the Wsl-Manager
PowerShell module. The project uses [Pester](https://pester.dev/), PowerShell's
testing framework, to ensure code quality and reliability.

## Testing Framework

Wsl-Manager uses **Pester v5** for unit testing. Pester provides:

-   A behavior-driven development (BDD) syntax with `Describe`, `Context`, and
    `It` blocks
-   Mock functionality to isolate units under test
-   Assertion capabilities with `Should` operators
-   Test organization and reporting features

## Test Structure

### Test Files

Test files follow the naming convention `*.Tests.ps1` and are located in the
root module directory:

-   `Wsl-RootFS.Tests.ps1` - Tests for the root filesystem management
    functionality
-   `Wsl-Manager.Tests.ps1` - Tests for the Wsl-Manager module

### Test Organization

Tests are organized using Pester's hierarchical structure:

```powershell
Describe "WslRootFileSystem" {
    BeforeAll {
        # Setup code that runs once before all tests
    }

    BeforeEach {
        # Setup code that runs before each test
    }

    It "should split Incus names" {
        # Individual test case
    }

    It "Should fail on bad Incus names" {
        # Another test case
    }
}
```

## Running Tests

### Prerequisites

1. **Install Pester** (if not already installed):

    ```powershell
    Install-Module -Name Pester -Force -SkipPublisherCheck
    ```

2. **Navigate to the module directory**:
    ```powershell
    cd "C:\Users\YourName\Documents\WindowsPowerShell\Modules\Wsl-Manager"
    ```

### Running All Tests

To run all tests in the module:

```powershell
Invoke-Pester
```

### Running Specific Test Files

To run tests from a specific file:

```powershell
Invoke-Pester -Path ".\Wsl-RootFS.Tests.ps1"
```

### Running Tests with Detailed Output

For verbose output showing all test results:

```powershell
Invoke-Pester -Output Detailed
```

### Running Tests with Code Coverage

To generate code coverage reports:

```powershell
Invoke-Pester -CodeCoverage ".\Wsl-RootFS.psm1"
```

## Writing Tests

### Test File Structure

Each test file should:

1. Import the module being tested
2. Update type and format data if needed
3. Define global test constants
4. Organize tests in `Describe` blocks

Example:

```powershell
using namespace System.IO;
using module .\Wsl-RootFS.psm1

Update-TypeData -PrependPath .\Wsl-Manager.Types.ps1xml
Update-FormatData -PrependPath .\Wsl-Manager.Format.ps1xml

# Define global constants
$global:EmptyHash = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

Describe "WslRootFileSystem" {
    # Tests go here
}
```

### Using Test Setup and Teardown

#### BeforeAll/AfterAll

Runs once before/after all tests in a `Describe` block:

```powershell
Describe "WslRootFileSystem" {
    BeforeAll {
        [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($(Join-Path $TestDrive "WslRootFS"))
        [WslRootFileSystem]::BasePath.Create()
    }

    AfterAll {
        # Cleanup code
    }
}
```

#### BeforeEach/AfterEach

Runs before/after each individual test:

```powershell
BeforeEach {
    Mock Sync-File {
        Write-Host "####> Mock download to $($File.FullName)..."
        New-Item -Path $File.FullName -ItemType File
    } -ModuleName Wsl-Manager
}
```

### Writing Test Cases

#### Basic Test Structure

```powershell
It "should split Incus names" {
    # Arrange
    $expected = "almalinux"

    # Act
    $rootFs = [WslRootFileSystem]::new("incus:almalinux:9", $false)

    # Assert
    $rootFs.Os | Should -Be $expected
    $rootFs.Release | Should -Be "9"
    $rootFs.Type -eq [WslRootFileSystemType]::Incus | Should -BeTrue
}
```

#### Testing Exceptions

```powershell
It "Should fail on bad Incus names" {
    { [WslRootFileSystem]::new("incus:badlinux:9") } | Should -Throw "Unknown Incus distribution*"
}
```

#### Testing with Try/Finally Blocks

For tests that create resources:

```powershell
It "Should download distribution" {
    try {
        # Test setup
        $rootFs = [WslRootFileSystem]::new("alpine", $true)

        # Test execution
        $rootFs | Sync-WslRootFileSystem

        # Assertions
        $rootFs.IsAvailableLocally | Should -BeTrue
    }
    finally {
        # Cleanup
        $path = [WslRootFileSystem]::BasePath.FullName
        Get-ChildItem -Path $path | Remove-Item
    }
}
```

### Using Mocks

Mocks isolate the code under test by replacing dependencies with controlled
implementations.

#### Basic Mock

```powershell
Mock Sync-File {
    Write-Host "####> Mock download to $($File.FullName)..."
    New-Item -Path $File.FullName -ItemType File
}
```

#### Mock with Return Values

```powershell
Mock Sync-String {
    return @"
$global:EmptyHash  miniwsl.alpine.rootfs.tar.gz
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
"@
}
```

#### Mock that Throws Exceptions

```powershell
Mock Get-DockerImageLayer {
    throw [System.Net.WebException]::new("test", 7)
}
```

#### Verifying Mock Calls

```powershell
Should -Invoke -CommandName Sync-File -Times 1
Should -Invoke -CommandName Get-DockerImageLayer -Times 0
```

### Common Assertions

#### Equality

```powershell
$result | Should -Be $expected
$result | Should -Not -Be $unexpected
```

#### Type Checking

```powershell
$result | Should -BeOfType [WslRootFileSystem]
$result.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
```

#### Null/Empty Checking

```powershell
$result | Should -Not -BeNullOrEmpty
$result | Should -BeNullOrEmpty
```

#### Collection Testing

```powershell
$collection.Length | Should -Be 5
$collection | Should -Contain $expectedItem
```

#### Exception Testing

```powershell
{ Some-Command } | Should -Throw
{ Some-Command } | Should -Throw "Expected error message*"
```

### Using TestDrive

Pester provides `$TestDrive` for creating temporary files and directories:

```powershell
BeforeAll {
    [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($(Join-Path $TestDrive "WslRootFS"))
    [WslRootFileSystem]::BasePath.Create()
}
```

## Test Organization Best Practices

### 1. Arrange-Act-Assert Pattern

Structure tests clearly:

```powershell
It "should do something" {
    # Arrange - Set up test data and conditions
    $input = "test-value"

    # Act - Execute the code being tested
    $result = Invoke-Function -Parameter $input

    # Assert - Verify the expected outcome
    $result | Should -Be "expected-value"
}
```

### 2. Descriptive Test Names

Use descriptive names that explain what is being tested:

```powershell
It "should split Incus names into OS and Release components" { }
It "should throw exception for invalid Incus distribution names" { }
It "should download distribution when not present locally" { }
```

### 3. InModuleScope for Internal Testing

Use `InModuleScope` to test internal module functions:

```powershell
InModuleScope "Wsl-RootFS" {
    It "should test internal function" {
        # Can access module-internal functions and variables
    }
}
```

### 4. Cleanup in Finally Blocks

Always clean up resources:

```powershell
try {
    # Test code
}
finally {
    Get-ChildItem -Path $testPath | Remove-Item
    [WslRootFileSystem]::HashSources.Clear()
}
```

## Example Test Suite

Here's a complete example of a test suite:

```powershell
using namespace System.IO;
using module .\Wsl-RootFS.psm1

Describe "WslRootFileSystem URL Parsing" {
    Context "When parsing Incus distribution names" {
        It "should extract OS and Release from valid Incus format" {
            # Arrange
            $incusName = "incus:almalinux:9"

            # Act
            $rootFs = [WslRootFileSystem]::new($incusName, $false)

            # Assert
            $rootFs.Os | Should -Be "almalinux"
            $rootFs.Release | Should -Be "9"
            $rootFs.Type | Should -Be ([WslRootFileSystemType]::Incus)
        }

        It "should throw exception for invalid Incus distribution" {
            # Act & Assert
            { [WslRootFileSystem]::new("incus:badlinux:9") } | Should -Throw "*Unknown Incus distribution*"
        }
    }

    Context "When parsing external URLs" {
        It "should extract filename components from URL" {
            # Arrange
            $url = "https://example.com/kalifs-amd64-minimal.tar.xz"

            # Act
            $rootFs = [WslRootFileSystem]::new($url)

            # Assert
            $rootFs.Os | Should -Be "Kalifs"
            $rootFs.Release | Should -Be "unknown"
            $rootFs.Type | Should -Be ([WslRootFileSystemType]::Uri)
        }
    }
}
```

## Continuous Integration

Tests are run automatically by Github Actions on each commit on a pull request.
This ensures that any changes made to the codebase are validated against the
test suite, helping to catch issues early.

## Testing Guidelines

1. **Write tests first** (Test-Driven Development) when adding new features
2. **Test edge cases** and error conditions, not just happy paths
3. **Use meaningful test names** that describe the expected behavior
4. **Keep tests independent** - each test should work in isolation
5. **Mock external dependencies** to ensure tests are fast and reliable
6. **Clean up resources** in `finally` blocks to prevent test pollution
7. **Use appropriate assertions** that provide clear failure messages
8. **Group related tests** using `Context` blocks for better organization

By following these practices, you'll create a robust test suite that helps
maintain code quality and prevents regressions as the module evolves.
