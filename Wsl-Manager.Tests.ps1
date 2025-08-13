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

        function Invoke-MockList() {
            Mock Wrap-Wsl -ModuleName "Wsl-Manager"  {
                return $global:fixture_wsl_list.Split([Environment]::NewLine)
            }
        }
        function Invoke-MockDownload() {
            Mock Get-DockerImageLayer -ModuleName "Wsl-RootFS" {
                Progress "Mock getting Docker image layer for $($DestinationFile)..."
                New-Item -Path $DestinationFile -ItemType File | Out-Null
                return $global:EmptyHash
              }
        }
    }

    It "should get distributions" {
        Invoke-MockList
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
        Invoke-MockList
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
        Mock Wrap-Wsl-Raw -ModuleName "Wsl-Manager" {
            if ($global:IsWindows) {
                New-Item -Path "TestRegistry:\Lxss" -Name "distro" -ItemType Container -Force | Out-Null
                New-ItemProperty -Path "TestRegistry:\Lxss\distro" -Name "DistributionName" -Value "distro" -PropertyType String -Force | Out-Null
                New-ItemProperty -Path "TestRegistry:\Lxss\distro" -Name "DefaultUid" -Value 0 -PropertyType DWord -Force | Out-Null
            }
            return ""  # Mock the import command
        }
        Install-Wsl -Name distro -Distribution alpine
        # Check that the directory was created
        Test-Path (Join-Path -Path ([WslDistribution]::DistrosRoot).FullName -ChildPath "distro") | Should -BeTrue
        if ($global:IsWindows) {
            # Check that the registry key was created
            Test-Path "TestRegistry:\Lxss\distro" | Should -BeTrue
            $uidProperty = Get-Item -Path "TestRegistry:\Lxss\distro"
            $uidProperty.GetValue('DefaultUid') | Should -Be 1000
            Test-Path "$([WslDistribution]::DistrosRoot.FullName)\distro" | Should -BeTrue
        }
    }
}
