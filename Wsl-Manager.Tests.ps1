using namespace System.IO;
using module .\Wsl-Manager.psm1

Update-TypeData -PrependPath .\Wsl-Manager.Types.ps1xml
Update-FormatData -PrependPath .\Wsl-Manager.Format.ps1xml

# cSpell: disable
$global:fixture_wsl_list = @"
  NAME           STATE           VERSION
* base           Stopped         2
  goarch         Stopped         2
  alpine322      Running         2
  alpine321      Stopped         2
"@
# cSpell: enable

# $global:IsWindows = $env:OS -eq "Windows_NT"
Write-Host "Is Windows: $($global:IsWindows)"

$global:Registry = @{}

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module "$PSScriptRoot/TestAssertions.psm1" -DisableNameChecking
}

Describe "WslDistribution" {
    BeforeAll {
        $wslRoot = Join-Path $TestDrive "Wsl"
        [WslDistribution]::DistrosRoot = [DirectoryInfo]::new($wslRoot)
        [WslDistribution]::DistrosRoot.Create()
        [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($(Join-Path $wslRoot "RootFS"))
        [WslRootFileSystem]::BasePath.Create()
        if ($global:IsWindows) {
            # Create a mock registry path for testing
            New-Item -Path TestRegistry:\ -Name Lxss -ItemType Container -Force | Out-Null
            [WslDistribution]::BaseDistributionsRegistryPath = "TestRegistry:\Lxss"
        }

        function Invoke-MockGet-WslRegistryKey() {
            class MockRegistryKey {
                [string]$Name
                [string]$Key
                MockRegistryKey([string]$Name) {
                    $this.Name = [Guid]::NewGuid().ToString()
                    $this.Key = $Name
                    if (-not $global:Registry.ContainsKey($this.Key)) {
                        $path = Join-Path ([WslDistribution]::DistrosRoot).FullName $Name
                        New-Item -Path $path -ItemType Directory -Force | Out-Null
                        $global:Registry[$this.Key] = [hashtable]@{
                            DistributionName = $Name
                            DefaultUid = 0
                            BasePath = $path
                        }
                    }
                }
                [object] GetValue([string]$Name) {
                    $value = $global:Registry[$this.Key][$Name]
                    return $value
                }

                [object] GetValue([string]$Name, [object]$defaultValue) {
                    $entry = $global:Registry[$this.Key]
                    if (-not $entry.ContainsKey($Name)) {
                        return $defaultValue
                    }
                    $value = $entry[$Name]
                    return $value
                }

                [void] SetValue([string]$Name, [object]$Value) {
                    $global:Registry[$this.Key][$Name] = $Value
                }
                [void] Close() {

                }
            }
            Mock Get-WslRegistryKey -ModuleName "Wsl-Manager"  {
                return [MockRegistryKey]::new($DistroName)
            }
        }

        function Invoke-Mock-Wrap-Wsl() {
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                return $global:fixture_wsl_list.Split([Environment]::NewLine)
            } -ParameterFilter {
                $args[0] -eq '--list'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                return ""
            } -ParameterFilter {
                $args[0] -eq '--terminate'
            } -Verifiable

        }
        function Invoke-MockDownload() {
            Mock Get-DockerImageLayer -ModuleName "Wsl-RootFS" {
                Progress "Mock getting Docker image layer for $($DestinationFile)..."
                New-Item -Path $DestinationFile -ItemType File | Out-Null
                return $global:EmptyHash
              }
        }
        function Invoke-Mock-Wrap-Wsl-Raw {
            Mock Wrap-Wsl-Raw -ModuleName "Wsl-Manager" {
                return "created"
            }
        }
        Invoke-MockGet-WslRegistryKey
    }

    AfterEach {
        $global:Registry.Clear()
    }

    It "should get distributions" {
        Invoke-Mock-Wrap-Wsl
        InModuleScope "Wsl-Manager" {  # Get-WslHelper is not exported
            $distros = Get-WslHelper
            $distros.Length | Should -Be 4
            $distros[0] | Should -BeOfType [WslDistribution]
            $distros[0].Name | Should -Be "base"
            $distros[0].Default | Should -Be $true
            $distros[2].State | Should -Be "Running"
        }
    }

    It "should filter distributions" {
        Invoke-Mock-Wrap-Wsl
        $distros = Get-Wsl
        $distros.Length | Should -Be 4

        $distros = Get-Wsl alpine*
        $distros.Length | Should -Be 2

        $distros = Get-Wsl -Default
        $distros | Should -BeOfType [WslDistribution]
        $distros.Name | Should -Be "base"

        $distros = Get-Wsl -State Running
        $distros | Should -BeOfType [WslDistribution]
        $distros.Name | Should -Be "alpine322"
    }

    It "should fail creating existing distribution" {
        # For that we need to mock a rootfs and then mock the call to import
        { Install-Wsl alpine322 -Distribution alpine | Should -Throw }
    }

    It "should create distribution" {
        Invoke-MockDownload
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Install-Wsl -Name distro -Distribution alpine
        # Check that the directory was created
        Test-Path (Join-Path -Path ([WslDistribution]::DistrosRoot).FullName -ChildPath "distro") | Should -BeTrue
        $global:Registry.ContainsKey("distro") | Should -Be $true "The registry should have a key for distro"
        $key = $global:Registry["distro"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "distro" "The DistributionName property should be set to 'distro'"
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
    }

    It "should stop distribution" {
        Invoke-Mock-Wrap-Wsl
        $wsl = Get-Wsl -Name "alpine322"
        $wsl.State | Should -Be "Running"
        Stop-Wsl -Name "alpine322"
        Should -InvokeVerifiable
    }


    It "should change the default user" {
        Invoke-Mock-Wrap-Wsl
        $wsl = Get-Wsl -Name "alpine322"
        $wsl.DefaultUid | Should -Be 0
        Set-WslDefaultUid -Name "alpine322" -Uid 1001
        $wsl = Get-Wsl -Name "alpine322"
        $wsl.DefaultUid | Should -Be 1001
    }
}
