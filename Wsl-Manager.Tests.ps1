using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification='This is a test file, global variables are used to share fixtures across tests.')]
Param()

BeforeAll {
    Import-Module Wsl-Manager
}

# cSpell: disable
$global:fixture_wsl_list = @"
  NAME           STATE           VERSION
* base           Stopped         2
  goarch         Stopped         2
  alpine322      Running         2
  alpine321      Stopped         2
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

$global:Registry = @{}
class MockRegistryKey {
    [string]$Name
    [string]$Key
    MockRegistryKey([string]$Name) {
        $this.Name = [Guid]::NewGuid().ToString()
        $this.Key = $Name
        if (-not $global:Registry.ContainsKey($this.Key)) {
            $path = Join-Path $global:wslRoot $Name
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            $global:Registry[$this.Key] = [hashtable]@{
                DistributionName = $Name
                DefaultUid = 0
                BasePath = $path
                Guid = $this.Name
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

class MockBaseKey {
    [hashtable]$Values = @{}

    MockRegistryKey() {
        # Create some default distributions.  cspell:disable-next-line
        $instances = @("base", "goarch", "alpine322", "alpine321") | ForEach-Object { [MockRegistryKey]::new($_) }
        $this.Values['DefaultDistribution'] = $instances[0].Guid
    }

    [string[]]GetSubKeyNames() {
        return $global:Registry.Values | ForEach-Object { $_.Guid }
    }

    [object] OpenSubKey([string]$Name, [bool]$Writable) {
        $actualName = $global:Registry.Values | Where-Object { $_.Guid -eq $Name } | Select-Object -First 1 | Select-Object -ExpandProperty DistributionName
        return [MockRegistryKey]::new($actualName)
    }

    [void] SetValue([string]$Name, [object]$Value) {
        $this.Values[$Name] = $Value
    }

    [object] GetValue([string]$Name) {
        return $this.Values[$Name]
    }

    [object] GetValue([string]$Name, [object]$defaultValue) {
        if (-not $this.Values.ContainsKey($Name)) {
            return $defaultValue
        }
        $value = $this.Values[$Name]
        return $value
    }

    [void] Close() {
    }
}
$global:RegistryBaseKey = [MockBaseKey]::new()

$global:AlpineFilename = 'docker.alpine.rootfs.tar.gz'

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module "$PSScriptRoot/TestAssertions.psm1" -DisableNameChecking
}

Describe "WslInstance" {
    BeforeAll {
        $global:wslRoot = Join-Path $TestDrive "Wsl"
        $global:ImageRoot = Join-Path $global:wslRoot "Image"
        [WslInstance]::DistrosRoot = [DirectoryInfo]::new($global:wslRoot)
        [WslInstance]::DistrosRoot.Create()
        [WslImage]::BasePath = [DirectoryInfo]::new($global:ImageRoot)
        [WslImage]::BasePath.Create()
        if ($global:IsWindows) {
            # Create a mock registry path for testing
            New-Item -Path TestRegistry:\ -Name Lxss -ItemType Container -Force | Out-Null
            [WslInstance]::BaseInstancesRegistryPath = "TestRegistry:\Lxss"
        }

        function Invoke-MockGet-WslRegistryKey() {
            Mock Get-WslRegistryKey -ModuleName "Wsl-Manager"  {
                return [MockRegistryKey]::new($DistroName)
            }
            Mock Get-WslRegistryBaseKey -ModuleName "Wsl-Manager" {
                return $global:RegistryBaseKey
            } -Verifiable
        }

        function Invoke-Mock-Wrap-Wsl() {
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                $result = $global:fixture_wsl_list.Split("`n")
                return $result
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--list'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                return ""
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--terminate'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                return ""
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--unregister'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                if ('gzip' -eq $PesterBoundParameters.Arguments[-2]) {
                    Write-Host "(Mock) Compressing (gzip) $($PesterBoundParameters.Arguments[-1])"
                    New-Item -Path $global:ImageRoot -Name "$($PesterBoundParameters.Arguments[-1]).gz" -ItemType File | Out-Null
                    return "done"
                } else {
                    Write-Host "(Mock) Executing $($PesterBoundParameters.Arguments)"
                    $result = $global:AlpineOSRelease.Split("`n")
                    return $result
                }
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--distribution' -and $PesterBoundParameters.Arguments[1] -ilike 'alpine*'
            } -Verifiable
            Mock Wrap-Wsl -ModuleName "Wsl-Manager" {
                Write-Host "(Mock) Exporting $($PesterBoundParameters.Arguments[1]) to $($PesterBoundParameters.Arguments[2])"
                New-Item -Path $PesterBoundParameters.Arguments[2] -ItemType File | Out-Null
                return "done"
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--export' -and $PesterBoundParameters.Arguments[1] -ilike 'alpine*'
            } -Verifiable
        }
        function Invoke-MockDownload() {
            Mock Get-DockerImageLayer -ModuleName "Wsl-Manager" {
                Write-Host "Mock getting Docker image layer for $($DestinationFile)..."
                New-Item -Path $DestinationFile -ItemType File | Out-Null
                return $global:EmptyHash
              }
        }
        function Invoke-Mock-Wrap-Wsl-Raw {
            Mock Wrap-Wsl-Raw -ModuleName "Wsl-Manager" {
                if ($global:IsWindows) {
                    timeout.exe /t 0 | Out-Null
                } else {
                    /bin/true | Out-Null
                }
            } -Verifiable
            Mock Wrap-Wsl-Raw -ModuleName "Wsl-Manager" {
                Write-Host "(Mock) Executing $($PesterBoundParameters.Arguments)"
                Write-Output $global:AlpineOSRelease.Split("`n")
                if ($global:IsWindows) {
                    timeout.exe /t 0 | Out-Null
                } else {
                    /bin/true | Out-Null
                }
            } -ParameterFilter {
                $PesterBoundParameters.Arguments[0] -eq '--distribution' -and $PesterBoundParameters.Arguments[1] -ilike 'alpine*'
            } -Verifiable
        }
        Invoke-MockGet-WslRegistryKey
    }

    AfterEach {
        $global:Registry.Clear()
        Get-ChildItem -Path $global:wslRoot -Recurse -File | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    It "should get distributions" {
        Invoke-Mock-Wrap-Wsl
        InModuleScope "Wsl-Manager" {  # Get-WslHelper is not exported
            $distros = Get-WslHelper
            $distros.Length | Should -Be 4
            $distros[0] | Should -BeOfType [WslInstance]
            $distros[0].Name | Should -Be "base"
            $distros[0].Default | Should -Be $true
            $distros[2].State | Should -Be "Running"
        }
    }

    It "should filter distributions" {
        Invoke-Mock-Wrap-Wsl
        $distros = Get-WslInstance
        $distros.Length | Should -Be 4

        $distros = Get-WslInstance alpine*
        $distros.Length | Should -Be 2

        $distros = Get-WslInstance -Default
        $distros | Should -BeOfType [WslInstance]
        $distros.Name | Should -Be "base"

        $distros = Get-WslInstance -State Running
        $distros | Should -BeOfType [WslInstance]
        $distros.Name | Should -Be "alpine322"
    }

    It "should fail creating existing distribution" {
        # For that we need to mock a Image and then mock the call to import
        { New-WslInstance alpine322 -From alpine | Should -Throw }
    }

    It "should create distribution" {
        Invoke-MockDownload
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        New-WslInstance -Name distro -From alpine
        # Check that the directory was created
        Test-Path (Join-Path -Path $global:wslRoot -ChildPath "distro") | Should -BeTrue
        $global:Registry.ContainsKey("distro") | Should -Be $true "The registry should have a key for distro"
        $key = $global:Registry["distro"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "distro" "The DistributionName property should be set to 'distro'"
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName "Wsl-Manager" -ParameterFilter {
            $expected = @(
                '--import',
                'distro',
                (Join-Path $global:wslRoot "distro"),
                (Join-Path $global:ImageRoot $global:AlpineFilename)
            )
            $result = Compare-Object -ReferenceObject $PesterBoundParameters.Arguments -DifferenceObject $expected -SyncWindow 0
            $result.Count -eq 0
        }
    }

    It "Should not install existing distribution" {
        Invoke-MockDownload
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        { New-WslInstance -Name alpine322 -From alpine | Should -Throw "The distribution 'alpine322' already exists." }
    }

    It "Should delete distribution" {
        Invoke-Mock-Wrap-Wsl
        Remove-WslInstance -Name "alpine322"
        Should -Invoke -CommandName Wrap-Wsl -Times 1 -ModuleName "Wsl-Manager" -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--unregister' -and $PesterBoundParameters.Arguments[1] -eq 'alpine322'
        }
    }
    It "Shouldn't delete non-existing distribution" {
        Invoke-Mock-Wrap-Wsl
        { Remove-WslInstance -Name "non-existing" | Should -Throw "The distribution 'non-existing' does not exist." }
        Should -Invoke -CommandName Wrap-Wsl -Times 0 -ModuleName "Wsl-Manager" -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--unregister' -and $PesterBoundParameters.Arguments[1] -eq 'non-existing'
        }
    }

    It "should stop distribution" {
        Invoke-Mock-Wrap-Wsl
        $wsl = Get-WslInstance -Name "alpine322"
        $wsl.State | Should -Be "Running"
        Stop-WslInstance -Name "alpine322"
        Should -Invoke -CommandName Wrap-Wsl -Times 1 -ModuleName "Wsl-Manager" -ParameterFilter {
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
    }

    It "Should rename the distribution" {
        Invoke-Mock-Wrap-Wsl
        Rename-WslInstance -Name "alpine322" -NewName "alpine323"
        $global:Registry.ContainsKey("alpine322") | Should -Be $true "The registry should have a key for alpine322"
        $key = $global:Registry["alpine322"]
        $key.ContainsKey("DistributionName") | Should -Be $true "The registry key should have a DistributionName property"
        $key["DistributionName"] | Should -Be "alpine323" "The DistributionName property should be set to 'alpine323'"
    }

    It "Should export the distribution" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        $wsl = Export-WslInstance "alpine322" "toto"
        $wsl | Should -BeOfType [WslImage]
        Test-Path (Join-Path $global:ImageRoot "toto.rootfs.tar.gz.json") | Should -Be $true
        Test-Path (Join-Path $global:ImageRoot "toto.rootfs.tar.gz") | Should -Be $true
    }

    It "Should call the command in the distribution" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Invoke-WslInstance -In "alpine322" cat /etc/os-release
        Should -Invoke -CommandName Wrap-Wsl -Times 1 -ModuleName "Wsl-Manager" -ParameterFilter {
            $PesterBoundParameters.Arguments[0] -eq '--list'
        }
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName "Wsl-Manager" -ParameterFilter {
            Write-Host "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
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

    It "Should configure the distribution" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        Invoke-WslConfigure -Name "alpine322"
        $global:Registry.ContainsKey("alpine322") | Should -Be $true "The registry should have a key for alpine322"
        $key = $global:Registry["alpine322"]
        $key.ContainsKey("DefaultUid") | Should -Be $true "The registry key should have a DefaultUid property"
        $key["DefaultUid"] | Should -Be 1000
        Should -Invoke -CommandName Wrap-Wsl-Raw -Times 1 -ModuleName "Wsl-Manager" -ParameterFilter {
            Write-Host "Invoking Wrap-Wsl with args: $($PesterBoundParameters.Arguments)"
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
    }

    It "Should change default instance" {
        Invoke-Mock-Wrap-Wsl
        Invoke-Mock-Wrap-Wsl-Raw
        $global:RegistryBaseKey.Values["DefaultDistribution"] | Should -Be $global:Registry["base"].Guid "The current default should be 'base'"
        Set-WslDefaultInstance -Name "alpine322"
        $global:RegistryBaseKey.Values.ContainsKey("DefaultDistribution") | Should -BeTrue "The registry should have a key for DefaultDistribution"
        $global:RegistryBaseKey.Values["DefaultDistribution"] | Should -Be $global:Registry["alpine322"].Guid "The Guid of the default instance should be the same as alpine322"
        Should -Invoke -CommandName Get-WslRegistryBaseKey -Times 1 -ModuleName "Wsl-Manager"
    }
}
