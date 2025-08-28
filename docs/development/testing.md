# Testing

This document explains how to write and execute tests for the Wsl-Manager
PowerShell module. The project uses [Pester](https://pester.dev/), PowerShell's
testing framework, to ensure code quality and reliability.

## Testing Framework

Wsl-Manager uses **Pester v5** for unit testing. Pester provides:

- A behavior-driven development (BDD) syntax with `Describe`, `Context`, and
  `It` blocks
- Mock functionality to isolate units under test
- Assertion capabilities with `Should` operators
- Test organization and reporting features

!!! info "Code Coverage Target"

    The project maintains a code coverage target of
    **85%** to ensure comprehensive testing of all functionality. Coverage reports
    are published to
    [CodeCov](https://app.codecov.io/gh/antoinemartin/PowerShell-Wsl-Manager) for
    monitoring and tracking.

## Test Structure

### Test Files

Test files follow the naming convention `*.Tests.ps1` and are located in the
`tests/` directory:

- `tests/Wsl-Image.Tests.ps1` - Tests for the image management functionality
- `tests/Wsl-Image.Docker.Tests.ps1` - Tests for Docker image functionality
- `tests/Wsl-Instance.Tests.ps1` - Tests for WSL instance management

### Test Organization

Tests are organized using Pester's hierarchical structure:

```powershell
Describe "WslImage" {
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

### Test Utility Modules

The project includes several utility modules in the `tests/` directory to
support testing:

#### TestUtils.psm1

A comprehensive utility module that provides:

- **Mock Management**: Functions for creating web response mocks, HTTP error
  mocks, and source data mocks
- **Test Data**: Pre-defined mock objects for builtin distributions, Incus
  sources, and ETag handling
- **Fixture Support**: Functions to load test fixture files from
  `tests/fixtures/`
- **Test Output**: Colored output functions with emoji indicators for better
  test readability

```powershell
# Example usage
New-BuiltinSourceMock -Tag "MockETag"
Add-InvokeWebRequestFixtureMock -SourceUrl $url -FixtureName "config.json"
Write-Test "Testing image download functionality"
```

#### TestAssertions.psm1

Custom Pester assertions for domain-specific testing:

- **HaveProperty**: Validates that objects have expected properties

```powershell
# Example usage
$image | Should -HaveProperty "Name"
$instance | Should -Not -HaveProperty "InvalidProperty"
```

#### TestRegistryMock.psm1

Mock registry implementation for testing Windows registry interactions:

- **MockRegistryKey**: Simulates Windows registry keys for WSL distribution
  management
- **MockBaseKey**: Provides mock registry base key functionality with default
  distributions
- **Registry Simulation**: Creates temporary registry-like storage without
  affecting the actual registry

```powershell
# Example usage - automatic mock registry setup
$mockKey = [MockRegistryKey]::new("test-distribution")
$mockKey.SetValue("DistributionName", "TestDistro")
```

!!! tip "Registry Testing"

    The registry mock allows safe testing of WSL
    management operations without modifying the actual Windows registry or requiring
    WSL to be installed. It also allows running the tests on Linux.

### Test Fixtures

The `tests/fixtures/` directory contains pre-recorded HTTP responses and
configuration files used for testing:

- **Docker Registry Responses**: Mock responses for Docker image metadata,
  tokens, and configurations
- **JSON Configurations**: Sample configuration files for various distributions
- **API Responses**: Cached responses from external services to ensure test
  consistency

```powershell
# Loading fixtures in tests
$fixtureContent = Get-FixtureContent "docker_alpine_config.json"
Add-InvokeWebRequestFixtureMock -SourceUrl $apiUrl -FixtureName "alpine_manifest.json"
```

!!! note "Fixture Naming Convention"

    Fixture files use underscores to replace
    special characters from URLs:

    - `docker_antoinemartin_slash_powershell-wsl-manager_slash_alpine-base_colon_latest_config.json`
    - Maps to: `docker://antoinemartin/powershell-wsl-manager/alpine-base:latest` config

## Running Tests

### Prerequisites

1.  **Install Pester** (if not already installed):

    ```powershell
    Install-Module -Name Pester -Force -SkipPublisherCheck
    ```

2.  **Navigate to the module directory**:
    ```bash
    cd /path/to/PowerShell-Wsl-Manager
    ```

### Using the Test Script

The project includes a dedicated test script `hack/Invoke-Tests.ps1` for running
tests:

#### Run Focused Tests (Development Mode)

For development with detailed output and mock visibility:

```powershell
pwsh -File ./hack/Invoke-Tests.ps1
```

This mode:

- Shows detailed test output
- Displays mock call information
- Disables code coverage for faster execution
- Can be filtered to specific tests

The test script supports filtering for focused testing during development. In
`hack/Invoke-Tests.ps1`, uncomment and modify

```powershell
# $PesterConfiguration.Filter.FullName = "WslImage.*"
# $PesterConfiguration.Filter.FullName = "WslInstance.should create instance"
```

#### Run All Tests (CI Mode)

For comprehensive testing with code coverage:

```powershell
pwsh -File ./hack/Invoke-Tests.ps1 -All
```

This mode:

- Enables code coverage analysis
- Generates JUnit XML and coverage reports
- Uses normal verbosity output
- Runs the complete test suite

### Using VS Code Tasks

Tests can be executed directly from VS Code using the configured tasks:

!!! tip "VS Code Integration"

    Use `Ctrl+Shift+P` → "Tasks: Run Task" to access
    these options quickly.

#### Available Tasks

- **Run tests** - Execute tests in development mode with detailed output
- **Run All tests** - Execute complete test suite with coverage

#### Task Configuration

The tasks are defined in `.vscode/tasks.json` with cross-platform support:

```json
{
  "label": "Run tests",
  "linux": {
    "command": "pwsh",
    "args": ["-File", "./hack/Invoke-Tests.ps1"]
  },
  "type": "shell",
  "problemMatcher": ["$pester"],
  "group": "test"
}
```

### Direct Pester Commands

:exclamation: Running Pester directly is **discouraged** for the following
reasons:

- Since version 5, full configuration cannot be performed by command line
  parameters alone.
- Changes in the classes code need a new Powershell session to be started.
- CI uses the `hack/Invoke-Tests.ps1` script for consistency.

## Writing Tests

### Test File Structure

Each test file should:

1. Import required modules and testing utilities
2. Set up module imports and type data
3. Define test constants and setup
4. Organize tests in `Describe` blocks

Example:

```powershell
using namespace System.IO;

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
    # Load other script wide modules
    Import-Module (Join-Path $PSScriptRoot "TestRegistryMock.psm1") -Force
}

BeforeAll {
    # Load main module
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    # Load utility modules
    Import-Module -Name (Join-Path $PSScriptRoot "TestUtils.psm1") -Force
    # Wether to show mock calls (controlled by Invoke-Tests.ps1)
    Set-MockPreference ($true -eq $Global:PesterShowMock)
}

Describe "WslImage" {
    BeforeAll {
        # Initialize test utilities and mocks
        New-BuiltinSourceMock
        Set-MockPreference $true
    }

    # Tests go here
}
```

!!! warning "Module Import Path"

    Test files are located in the `tests/` directory, so main module import need to
    reference the parent directory with `Join-Path $PSScriptRoot ".."` to access the main module files.

### Using Test Setup and Teardown

#### BeforeAll/AfterAll

Runs once before/after all tests in a `Describe` block:

```powershell
Describe "WslImage" {
    BeforeAll {
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "Image"
        [MockRegistryKey]::WslRoot = $WslRoot
        [WslInstance]::DistrosRoot = [DirectoryInfo]::new($WslRoot)
        [WslInstance]::DistrosRoot.Create()
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
    }

    AfterAll {
        # Cleanup code
    }
}
```

#### BeforeEach/AfterEach

Runs before/after each individual test:

````powershell
BeforeEach {
    Mock Sync-File {
        # Will be rendered with a 🧪 prefix
        Write-Test "Mock download to $($File.FullName)..."
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
    $Image = [WslImage]::new("incus:almalinux:9", $false)

    # Assert
    $Image.Os | Should -Be $expected
    $Image.Release | Should -Be "9"
    $Image.Type -eq [WslImageType]::Incus | Should -BeTrue
}
````

#### Testing Exceptions

```powershell
It "Should fail on bad Incus names" {
    { [WslImage]::new("incus:badlinux:9") } | Should -Throw "Unknown Incus distribution*"
}
```

#### Testing with Try/Finally Blocks

For tests that create resources:

```powershell
It "Should download distribution" {
    try {
        # Test setup
        $Image = [WslImage]::new("alpine", $true)

        # Test execution
        $Image | Sync-WslImage

        # Assertions
        $Image.IsAvailableLocally | Should -BeTrue
    }
    finally {
        # Cleanup
        $path = [WslImage]::BasePath.FullName
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
    # Will be rendered with a 🤡 prefix
    Write-Mock "Mock download to $($File.FullName)..."
    New-Item -Path $File.FullName -ItemType File
} -Verifiable
```

#### Mock with Return Values

```powershell
Mock Sync-String {
    return @"
$global:EmptyHash  miniwsl.alpine.rootfs.tar.gz
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
"@
} -Verifiable
```

#### Mock that Throws Exceptions

```powershell
Mock Get-DockerImage {
    throw [System.Net.WebException]::new("test", 7)
}
```

#### Verifying Mock Calls

```powershell
Should -Invoke -CommandName Sync-File -Times 1
Should -Invoke -CommandName Get-DockerImage -Times 0
```

### Common Assertions

#### Equality

```powershell
$result | Should -Be $expected
$result | Should -Not -Be $unexpected
```

#### Type Checking

```powershell
$result | Should -BeOfType [WslImage]
$result.Type -eq [WslImageType]::Builtin | Should -BeTrue
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
    $WslRoot = Join-Path $TestDrive "Wsl"
    [WslInstance]::DistrosRoot = [DirectoryInfo]::new($WslRoot)
    [WslInstance]::DistrosRoot.Create()
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
InModuleScope "Wsl-Image" {
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
    [WslImage]::HashSources.Clear()
}
```

## Example Test Suite

Here's a complete example of a test suite:

```powershell
using namespace System.IO;
using module .\Wsl-Image.psm1

Describe "WslImage URL Parsing" {
    Context "When parsing Incus distribution names" {
        It "should extract OS and Release from valid Incus format" {
            # Arrange
            $incusName = "incus:almalinux:9"

            # Act
            $Image = [WslImage]::new($incusName, $false)

            # Assert
            $Image.Os | Should -Be "almalinux"
            $Image.Release | Should -Be "9"
            $Image.Type | Should -Be ([WslImageType]::Incus)
        }

        It "should throw exception for invalid Incus distribution" {
            # Act & Assert
            { [WslImage]::new("incus:badlinux:9") } | Should -Throw "*Unknown Incus distribution*"
        }
    }

    Context "When parsing external URLs" {
        It "should extract filename components from URL" {
            # Arrange
            $url = "https://example.com/kalifs-amd64-minimal.tar.xz"

            # Act
            $Image = [WslImage]::new($url)

            # Assert
            $Image.Os | Should -Be "Kalifs"
            $Image.Release | Should -Be "unknown"
            $Image.Type | Should -Be ([WslImageType]::Uri)
        }
    }
}
```

## Continuous Integration and Coverage

### GitHub Actions

Tests are run automatically by GitHub Actions on:

- Each commit on a pull request
- Merges to the main branch
- Manual workflow dispatch

The CI pipeline:

1. Sets up a PowerShell environment
2. Installs dependencies including Pester
3. Runs the complete test suite with coverage
4. Publishes test results and coverage reports

### Code Coverage Reporting

Code coverage is tracked and published to
**[CodeCov](https://app.codecov.io/gh/antoinemartin/PowerShell-Wsl-Manager)**:

- **Target**: Maintain 85% or higher code coverage
- **Format**: `CoverageGutters` format for local development, `JaCoCo` for CI
- **Scope**: Covers All the source files of the module except the
  `*.Helpers.ps1` files that are heavily mocked in tests.
- **Reporting**: Automatic uploads on successful CI runs

!!! success "Coverage Monitoring"

    The CodeCov integration provides:

    - **Pull Request Comments**: Coverage diff and impact analysis
    - **Branch Protection**: Prevents merging if coverage drops significantly
    - **Historical Tracking**: Coverage trends over time
    - **File-level Analysis**: Detailed coverage per module and function

## Testing Guidelines

### Development Practices

1. **Test working features** because the module is dependent on external
   dependencies and testing requires heavy mocking. Keep testing to avoid
   regressions.
2. **Test edge cases** and error conditions, not just happy paths
3. **Use meaningful test names** that describe the expected behavior
4. **Keep tests independent** - each test should work in isolation
5. **Mock external dependencies** to ensure tests are fast and reliable
6. **Clean up resources** in `finally` blocks to prevent test pollution
7. **Use appropriate assertions** that provide clear failure messages
8. **Group related tests** using `Context` blocks for better organization

### Coverage Requirements

!!! warning "Coverage Standards"

    - **Minimum coverage**: 85% across all modules
    - **New code**: Should have 90%+ coverage
    - **Critical paths**: Must have 100% coverage (authentication, data integrity)
    - **Exception handling**: Some error path may be skipped.

### Using Test Utilities

Leverage the provided utility modules:

```powershell
# Use TestUtils for consistent mocking
New-BuiltinSourceMock -Tag "v1.0.0"
Add-InvokeWebRequestFixtureMock -SourceUrl $url -FixtureName "response.json"

# Use custom assertions for better error messages
$result | Should -HaveProperty "ExpectedProperty"

# Use registry mocks for safe testing
[MockRegistryKey]::new("test-distro")
```

### Best Practices for Mocking

- **Mock external services**: HTTP requests, file system operations, registry
  access
- **Use fixtures**: Store test data in `tests/fixtures/` for complex responses
- **Verify mock calls**: Ensure mocks are called as expected
- **Reset state**: Clean up mocks between tests using `BeforeEach`/`AfterEach`

By following these practices, you'll create a robust test suite that helps
maintain code quality and prevents regressions as the module evolves.
