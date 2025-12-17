# cSpell: ignore testversion1
using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification='This is a test file, global variables are used to share fixtures across tests.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
Param()


# cSpell: disable
$global:fixture_wsl_list = @"
  NAME           STATE           VERSION
* base           Stopped         2
  goarch         Stopped         2
  alpine322      Running         2
  alpine321      Stopped         2
  testversion1   Stopped         1
"@

$global:AlpineOSRelease = @"
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.19.1
PRETTY_NAME="Alpine Linux v3.19"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
"@
# cSpell: enable


BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestRegistryMock.psm1") -Force
}

BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    Import-Module -Name (Join-Path $PSScriptRoot "TestUtils.psm1") -Force
    Set-MockPreference ($true -eq $Global:PesterShowMock)
}

Describe "WslInstance" {
    BeforeAll {
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "Image"
        [MockRegistryKey]::WslRoot = $WslRoot
        [WslInstance]::DistrosRoot = [DirectoryInfo]::new($WslRoot)
        [WslInstance]::DistrosRoot.Create()
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
        [WslImageDatabase]::DatabaseFileName = [FileInfo]::new((Join-Path $ImageRoot "images.db"))

        function Invoke-MockGet-WslRegistryKey() {
            Mock Get-WslRegistryKey -ModuleName Wsl-Manager  {
                Write-Mock "Get registry key for $DistroName"
                return [MockRegistryKey]::new($DistroName)
            }
            Mock Get-WslRegistryBaseKey -ModuleName Wsl-Manager {
                Write-Mock "Base Registry key"
                return [MockBaseKey]::Instance
            } -Verifiable
        }

        function Invoke-Mock-Wrap-Wsl() {
            Mock Wrap-Wsl -ModuleName Wsl-Manager {
                Write-Mock "wrap wsl $($PesterBoundParameters.Arguments -join " ")"
                $result = $global:fixture_wsl_list.Split("`n")
                return $result
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--list'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName Wsl-Manager {
                Write-Mock "wrap wsl $($PesterBoundParameters.Arguments -join " ")"
                return ""
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--terminate'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName Wsl-Manager {
                Write-Mock "wrap wsl $($PesterBoundParameters.Arguments -join " ")"
                return ""
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--unregister'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName Wsl-Manager {
                Write-Mock "wrap wsl $($PesterBoundParameters.Arguments -join " ")"
                if ('gzip' -eq $PesterBoundParameters.Arguments[-2]) {
                    New-Item -Path $PesterBoundParameters.Arguments[-3] -Name "$($PesterBoundParameters.Arguments[-1]).gz" -ItemType File | Out-Null
                    return "done"
                } else {
                    $result = $global:AlpineOSRelease.Split("`n")
                    return $result
                }
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--distribution' -and $PesterBoundParameters.Arguments[1] -ilike 'alpine*'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName Wsl-Manager {
                Write-Mock "wrap export wsl $($PesterBoundParameters.Arguments -join " ")"
                New-Item -Path $PesterBoundParameters.Arguments[2] -ItemType File | Out-Null
                return "done"
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--export' -and $PesterBoundParameters.Arguments[1] -ilike 'alpine*'
            } -Verifiable
        }
        function Invoke-Mock-Wrap-Wsl-Raw {
            Mock Wrap-Wsl-Raw -ModuleName Wsl-Manager {
                Write-Mock "wrap raw wsl $($PesterBoundParameters.Arguments -join " ")"
                if (-not $IsLinux -and (Get-Command 'timeout.exe' -ErrorAction SilentlyContinue)) {
                    timeout.exe /t 0 | Out-Null
                } else {
                    /bin/true | Out-Null
                }
            } -Verifiable
            Mock Wrap-Wsl-Raw -ModuleName Wsl-Manager {
                Write-Mock "wrap raw wsl $($PesterBoundParameters.Arguments -join " ")"
                Write-Output $global:AlpineOSRelease.Split("`n")
                if (-not $IsLinux -and (Get-Command 'timeout.exe' -ErrorAction SilentlyContinue)) {
                    timeout.exe /t 0 | Out-Null
                } else {
                    /bin/true | Out-Null
                }
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--distribution' -and $PesterBoundParameters.Arguments[1] -ilike 'alpine*'
            } -Verifiable
        }
        Invoke-MockGet-WslRegistryKey
        New-BuiltinSourceMock
        New-IncusSourceMock
    }

    BeforeEach {
        [MockBaseKey]::Reset()
    }

    AfterEach {
        InModuleScope -ModuleName Wsl-Manager {
            Close-WslImageDatabase
        }
        Get-ChildItem -Path $WslRoot -Recurse -File | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    It "should get instances" {
        Invoke-Mock-Wrap-Wsl
        InModuleScope "Wsl-Manager" {  # Get-WslHelper is not exported
            $distros = Get-WslHelper
            $distros.Length | Should -Be 5
            $distros[0] | Should -BeOfType [WslInstance]
            $distros[0].Name | Should -Be "base"
            $distros[0].Default | Should -Be $true
            $distros[2].State | Should -Be "Running"
        }
    }

    It "should filter instances" {
        Invoke-Mock-Wrap-Wsl
        $distros = Get-WslInstance
        $distros.Length | Should -Be 5

        $distros = Get-WslInstance alpine*
        $distros.Length | Should -Be 2

        $distros = Get-WslInstance -Default
        $distros | Should -BeOfType [WslInstance]
        $distros.Name | Should -Be "base"

        $distros = Get-WslInstance -State Running
        $distros | Should -BeOfType [WslInstance]
        $distros.Name | Should -Be "alpine322"

        $distros = @(Get-WslInstance -Version 1)
        $distros.Length | Should -Be 1
        $distros[0].Name | Should -Be "testversion1"

        $distros = @(Get-WslInstance -Version 2)
        $distros.Length | Should -Be 4
    }

    It "should fail creating existing instance" {
        # For that we need to mock a Image and then mock the call to import
        { New-WslInstance alpine322 -From alpine | Should -Throw }
    }

    It "should create instance" {
        New-GetDockerImageMock
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        New-WslInstance -Name distro -From alpine
        # Check that the directory was created
        Test-Path (Join-Path -Path $WslRoot -ChildPath "distro") | Should -BeTrue
        [MockRegistryKey]::RegistryByName.ContainsKey("distro") | Should -Be $true "The registry should have a key for distro"
        $key = [MockRegistryKey]::RegistryByName["distro"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "distro" "The DistributionName property should be set to 'distro'"
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $expected = @(
                '--import',
                'distro',
                (Join-Path $WslRoot "distro"),
                (Join-Path $ImageRoot $MockBuiltins[1].LocalFilename)
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }

        { New-WslInstance -Name distro -From non-builtin } | Should -Throw "The specified image 'non-builtin' does not exist or could not be retrieved."
    }

    It "should create and configure instance" {
        New-GetDockerImageMock
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        New-WslInstance -Name distro -From alpine-base -Configure
        # Check that the directory was created
        Test-Path (Join-Path -Path $WslRoot -ChildPath "distro") | Should -BeTrue
        [MockRegistryKey]::RegistryByName.ContainsKey("distro") | Should -Be $true "The registry should have a key for distro"
        $key = [MockRegistryKey]::RegistryByName["distro"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "distro" "The DistributionName property should be set to 'distro'"
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $expected = @(
                '--import',
                'distro',
                (Join-Path $WslRoot "distro"),
                (Join-Path $ImageRoot $MockBuiltins[0].LocalFilename)
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '-d',
                'distro',
                '-u',
                'root',
                './configure.sh'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

    It "should create but skip configuration on instance" {
        New-GetDockerImageMock
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        New-WslInstance -Name distro -From alpine -Configure
        # Check that the directory was created
        Test-Path (Join-Path -Path $WslRoot -ChildPath "distro") | Should -BeTrue
        [MockRegistryKey]::RegistryByName.ContainsKey("distro") | Should -Be $true "The registry should have a key for distro"
        $key = [MockRegistryKey]::RegistryByName["distro"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "distro" "The DistributionName property should be set to 'distro'"
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $expected = @(
                '--import',
                'distro',
                (Join-Path $WslRoot "distro"),
                (Join-Path $ImageRoot $MockBuiltins[1].LocalFilename)
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 0 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '-d',
                'distro',
                '-u',
                'root',
                './configure.sh'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

    It "Should not install existing instance" {
        New-GetDockerImageMock
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        { New-WslInstance -Name alpine322 -From alpine } | Should -Throw "WSL instance alpine322 already exists"
    }

    It "Should delete instance" {
        Invoke-Mock-Wrap-Wsl
        Remove-WslInstance -Name "alpine322"
        Should -Invoke -CommandName Wrap-Wsl -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--unregister' -and $PesterBoundParameters.Arguments[1] -eq 'alpine322'
        }
    }
    It "Shouldn't delete non-existing instance" {
        Invoke-Mock-Wrap-Wsl
        { Remove-WslInstance -Name "non-existing" | Should -Throw "The instance 'non-existing' does not exist." }
        Should -Invoke -CommandName Wrap-Wsl -Times 0 -ModuleName Wsl-Manager -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--unregister' -and $PesterBoundParameters.Arguments[1] -eq 'non-existing'
        }
    }

    It "should stop instance" {
        Invoke-Mock-Wrap-Wsl
        $wsl = Get-WslInstance -Name "alpine322"
        $wsl.State | Should -Be "Running"
        Stop-WslInstance -Name "alpine322"
        Should -Invoke -CommandName Wrap-Wsl -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--terminate' -and $PesterBoundParameters.Arguments[1] -eq 'alpine322'
        }
        $wsl = Get-WslInstance -Name "alpine322"
        $wsl.State | Should -Be "Running"
        Stop-WslInstance -Instance $wsl
        Should -Invoke -CommandName Wrap-Wsl -Times 2 -ModuleName Wsl-Manager -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--terminate' -and $PesterBoundParameters.Arguments[1] -eq 'alpine322'
        }
    }

    It "Should change the default user" {
        Invoke-Mock-Wrap-Wsl
        $wsl = Get-WslInstance -Name "alpine322"
        $wsl.DefaultUid | Should -Be 0
        Set-WslDefaultUid -Name "alpine322" -Uid 1001
        $wsl = Get-WslInstance -Name "alpine322"
        $wsl.DefaultUid | Should -Be 1001
        Set-WslDefaultUid -Instance $wsl -Uid 1002
        $wsl = Get-WslInstance -Name "alpine322"
        $wsl.DefaultUid | Should -Be 1002
    }

    It "Should rename the instance" {
        Invoke-Mock-Wrap-Wsl
        Rename-WslInstance -Name "alpine322" -NewName "alpine323"
        [MockRegistryKey]::RegistryByName.ContainsKey("alpine322") | Should -Be $true "The registry should have a key for alpine322"
        $key = [MockRegistryKey]::RegistryByName["alpine322"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "alpine323" "The DistributionName property should be set to 'alpine323'"
    }

    It "Shouldn't be able to rename to an existing instance" {
        Invoke-Mock-Wrap-Wsl
        { Rename-WslInstance -Name "alpine322" -NewName "alpine321" } | Should -Throw "WSL instance alpine321 already exists"
    }

    It "Should export the instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        $wsl = Export-WslInstance "alpine322" "toto"
        $wsl | Should -BeOfType [WslImage]
        Test-Path (Join-Path $ImageRoot "toto.rootfs.tar.gz.json") | Should -Be $true
        Test-Path (Join-Path $ImageRoot "toto.rootfs.tar.gz") | Should -Be $true
    }

    It "Should export with default name the instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        $wsl = Export-WslInstance "alpine322"
        $wsl | Should -BeOfType [WslImage]
        Test-Path (Join-Path $ImageRoot "alpine322.rootfs.tar.gz.json") | Should -Be $true
        Test-Path (Join-Path $ImageRoot "alpine322.rootfs.tar.gz") | Should -Be $true
    }

    It "Should export with default name and directory creation the instance" {
        $DestinationDir = Join-Path $WslRoot "subdir"
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        $wsl = Export-WslInstance "alpine322" -Destination $DestinationDir -Verbose
        $wsl | Should -BeOfType [WslImage]
        Test-Path (Join-Path $DestinationDir "alpine322.rootfs.tar.gz.json") | Should -Be $true
        Test-Path (Join-Path $DestinationDir "alpine322.rootfs.tar.gz") | Should -Be $true
    }

    It "Should call the command in the instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Invoke-WslInstance -In "alpine322" cat /etc/os-release
        Should -Invoke -CommandName Wrap-Wsl -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--list'
        }
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '--distribution',
                'alpine322',
                'cat',
                '/etc/os-release'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

    It "Should configure the instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw

        Write-Test "First configuration of the instance"
        Invoke-WslConfigure -Name "alpine322"
        [MockRegistryKey]::RegistryByName.ContainsKey("alpine322") | Should -Be $true "The registry should have a key for alpine322"
        $key = [MockRegistryKey]::RegistryByName["alpine322"]
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '-d',
                'alpine322',
                '-u',
                'root',
                './configure.sh'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
        Write-Test "Error because the instance is already configured"
        { Invoke-WslConfigure -Name "alpine322" } | Should -Throw

        Write-Test "Force reconfiguration of the instance"
        Invoke-WslConfigure -Name "alpine322" -Force
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 3 -ModuleName Wsl-Manager -Because "Should call to delete /etc/wsl-configured and to reconfigure"

        Write-Test "Test configuration script failure"
        Mock Wrap-Wsl-Raw -ModuleName Wsl-Manager {
            Write-Mock "wrap raw wsl $($PesterBoundParameters.Arguments -join " ") with failure"
            if (-not $IsLinux -and (Get-Command 'cmd.exe' -ErrorAction SilentlyContinue)) {
                & cmd.exe /c 'exit 1'
            } else {
                & /bin/false
            }
        } -ParameterFilter {
            $PesterBoundParameters.Arguments.Count -le 5 -and $PesterBoundParameters.Arguments[4] -eq './configure.sh'
        } -Verifiable

        { Invoke-WslConfigure -Name "alpine322" -Force } | Should -Throw "Configuration failed*"

    }

    It "Should change default instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        [MockBaseKey]::Instance.Values["DefaultDistribution"] | Should -Be ([MockRegistryKey]::RegistryByName["base"]).Guid "The current default should be 'base'"
        Set-WslDefaultInstance -Name "alpine322"
        [MockBaseKey]::Instance.Values.ContainsKey("DefaultDistribution") | Should -BeTrue "The registry should have a key for DefaultDistribution"
        [MockBaseKey]::Instance.Values["DefaultDistribution"] | Should -Be ([MockRegistryKey]::RegistryByName["alpine322"]).Guid "The Guid of the default instance should be the same as alpine322"
        Should -Invoke -CommandName Get-WslRegistryBaseKey -Times 1 -ModuleName Wsl-Manager
    }

    It "Should invoke the instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Invoke-WslInstance -In "alpine322" ls /
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '--distribution',
                'alpine322',
                'ls',
                '/'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

    It "Should invoke the default instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Invoke-WslInstance ls /
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '--distribution',
                'base',
                'ls',
                '/'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

    It "Should invoke as user the default instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Invoke-WslInstance -User arch ls /
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            Write-Test "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
            $expected = @(
                '--distribution',
                'base',
                '--user',
                'arch',
                'ls',
                '/'
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

}
