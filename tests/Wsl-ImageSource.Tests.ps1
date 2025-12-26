using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param()

# cSpell: ignore justaname mycustomimage unknowntype

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
}


BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    Import-Module -Name (Join-Path $PSScriptRoot "TestUtils.psm1") -Force

    Set-MockPreference ($true -eq $Global:PesterShowMock)
}

Describe "WslImageSource"  {
    BeforeAll {
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "RootFS"
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
        [WslImageDatabase]::DatabaseFileName = [FileInfo]::new((Join-Path $ImageRoot "images.db"))

        InModuleScope -ModuleName Wsl-Manager {
            $global:builtinsSourceUrl = $WslImageSources[[WslImageType]::Builtin]
            $global:incusSourceUrl = $WslImageSources[[WslImageType]::Incus]
        }

        $TestBuiltinImageName = "antoinemartin/powershell-wsl-manager/alpine-base"
        $TestExternalImageName = "antoinemartin/yawsldocker/yawsldocker-alpine"
        $TestDockerHubImageName = "library/alpine"
        $DockerHubRegistryDomain = "registry-1.docker.io"
        $TestTag = "latest"
        $TestMock = $MockBuiltins[3]
        $AlternateMock = $MockIncus[2]

        New-BuiltinSourceMock
        New-IncusSourceMock
    }

    BeforeEach {
    }

    AfterEach {
        InModuleScope -ModuleName Wsl-Manager {
            Close-WslImageDatabase
        }
        Get-ChildItem -Path ([WslImage]::BasePath).FullName | Remove-Item -Force
    }

    Context "Helpers" {
        It "Should get information from configured builtin tarball" {
            $metadata = New-MockImage -BasePath ([WslImage]::BasePath) `
                -Name "alpine" `
                -Os "Alpine" `
                -Release "3.22.1" `
                -Type "Builtin" `
                -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine#latest" `
                -LocalFileName "docker.alpine.rootfs.tar.gz" `
                -Configured $true `
                -Username "alpine" `
                -Uid 1000 `
                -CreateMetadata $false `
                -ErrorAction Stop `

            InModuleScope -ModuleName Wsl-Manager {
                $TarballPath = Join-Path ([WslImage]::BasePath).FullName $metadata.LocalFileName
                $info = Get-DistributionInformationFromTarball -File (Get-Item $TarballPath)
                $info.Distribution | Should -Be "Alpine"
                $info.Release | Should -Be "3.22.1"
                $info.Configured | Should -Be $true
                $info.Username | Should -Be "alpine"
                $info.Uid | Should -Be 1000
            } -Parameters @{'metadata' = $metadata}
        }

        It "Should get information from unconfigured incus tarball" {
            $metadata = New-MockImage -BasePath ([WslImage]::BasePath) `
                -Name "debian" `
                -Os "Debian" `
                -Release "12" `
                -Type "Incus" `
                -Url "incus://debian/bullseye" `
                -LocalFileName "incus.debian.rootfs.tar.gz" `
                -Configured $false `
                -Username "root" `
                -Uid 0 `
                -CreateMetadata $false `
                -ErrorAction Stop `

            InModuleScope -ModuleName Wsl-Manager {
                $TarballPath = Join-Path ([WslImage]::BasePath).FullName $metadata.LocalFileName
                $info = Get-DistributionInformationFromTarball -File (Get-Item $TarballPath)
                $info.Distribution | Should -Be "Debian"
                $info.Release | Should -Be "12"
                $info.ContainsKey("Configured") | Should -Be $false
                $info.ContainsKey("Username") | Should -Be $false
                $info.ContainsKey("Uid") | Should -Be $false
            } -Parameters @{'metadata' = $metadata}
        }

        It "Should get distribution information from a filename" {
            InModuleScope -ModuleName Wsl-Manager {
                $info = Get-DistributionInformationFromName -Name "docker.alpine.rootfs.tar.gz"
                $info.Name | Should -Be "alpine"
                $info.Type | Should -Be "Docker"

                $info = Get-DistributionInformationFromName -Name "incus.debian_12.rootfs.tar.gz"
                $info.Name | Should -Be "debian"
                $info.Release | Should -Be "12"
                $info.Type | Should -Be "Incus"

                $info = Get-DistributionInformationFromName -Name "builtin.ubuntu_22.04.rootfs.tar.gz"
                $info.Name | Should -Be "ubuntu"
                $info.Release | Should -Be "22.04"
                $info.Type | Should -Be "Builtin"

                $info = Get-DistributionInformationFromName -Name "mycustomimage.rootfs.tar.gz"
                $info.Name | Should -Be "mycustomimage"
                $info.ContainsKey("Type") | Should -Be $false

                $info = Get-DistributionInformationFromName -Name "unknowntype.mycustomimage.rootfs.tar.gz"
                $info.Name | Should -Be "mycustomimage"
                $info.ContainsKey("Type") | Should -Be $false

                $info = Get-DistributionInformationFromName -Name "mycustomimage_2.12.rootfs.tar.gz"
                $info.Name | Should -Be "mycustomimage"
                $info.Release | Should -Be "2.12"
                $info.ContainsKey("Type") | Should -Be $false

                $info = Get-DistributionInformationFromName -Name "justaname.tar.gz"
                $info.Name | Should -Be "justaname"
                $info.ContainsKey("Release") | Should -Be $false
                $info.ContainsKey("Type") | Should -Be $false

                { $null = Get-DistributionInformationFromName -Name "justaname" } | Should -Throw "Unknown image with OS justaname and Release  and type Builtin."

                $info.Name | Should -Be "justaname"
                $info.ContainsKey("Release") | Should -Be $false
                $info.ContainsKey("Type") | Should -Be $false

                $info = Get-DistributionInformationFromName "archlinux-2025.12.01.153427.wsl"
                $info.Name | Should -Be "archlinux"
                $info.Release | Should -Be "2025.12.01.153427"
            }
        }

        It "Should fetch distribution information from the a tarball and filename" {
            $metadata = New-MockImage -BasePath ([WslImage]::BasePath) `
                -Name "alpine" `
                -Os "Alpine" `
                -Release "3.22.1" `
                -Type "Builtin" `
                -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine#latest" `
                -LocalFileName "docker.alpine.rootfs.tar.gz" `
                -Configured $true `
                -Username "alpine" `
                -Uid 1000 `
                -CreateMetadata $false `
                -ErrorAction Stop `

            InModuleScope -ModuleName Wsl-Manager {
                $TarballPath = Join-Path ([WslImage]::BasePath).FullName $metadata.LocalFileName
                $info = Get-DistributionInformationFromFile -File (Get-Item $TarballPath)
                $info.Distribution | Should -Be "Alpine"
                $info.Release | Should -Be "3.22.1"
                $info.Configured | Should -Be $true
                $info.Username | Should -Be "alpine"
                $info.Uid | Should -Be 1000
                $info.Type | Should -Be "Docker"
                $info.FileHash | Should -Not -BeNullOrEmpty

                $uri = [Uri]::new("file://$TarballPath")
                Write-Verbose "Testing URI: $uri" -Verbose
                $info = Get-DistributionInformationFromUri -Uri $uri
                $info.Distribution | Should -Be "Alpine"
                $info.Release | Should -Be "3.22.1"
                $info.Configured | Should -Be $true
                $info.Username | Should -Be "alpine"
                $info.Uid | Should -Be 1000
                $info.Type | Should -Be "Docker"
                $info.FileHash | Should -Not -BeNullOrEmpty

                $NonExistentFile = [FileInfo]::new((Join-Path ([WslImage]::BasePath).FullName "nonexistent.tar.gz"))

                { Get-DistributionInformationFromFile -File $NonExistentFile } | Should -Throw "The specified file does not exist:*"
            } -Parameters @{'metadata' = $metadata}
        }

        It "Should handle tar command failure gracefully" {
            $path = $ImageRoot
            $localTarFile = "corrupted-distro.tar.gz"
            New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar command failure
            Mock -CommandName Invoke-Tar -MockWith {
                Write-Mock "Mocking tar extraction failure for $($args -join ' ')"
                throw [WslManagerException]::new("tar command failed with exit code 1. Output: `nBad input")
            } -ModuleName Wsl-Manager

            $file = Get-Item -Path (Join-Path -Path $path -ChildPath $localTarFile)

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            # Should still create the image but with fallback values
            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Name | Should -Be "Corrupted"
            $image.Distribution | Should -Be "Unknown"
            $image.Release | Should -Be "Distro"
        }

        It "Should handle os-release parsing exception gracefully" {
            $path = $ImageRoot
            $localTarFile = "malformed-distro.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction that returns malformed data causing ConvertFrom-StringData to fail
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "etc" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
ID=ubuntu-malformed-no-quotes-bad-format
VERSION_ID-malformed
invalid-line-without-equals
'@
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            # Should catch the exception and fall back to default values
            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Name | Should -Be "Malformed"
            $image.Release | Should -Be "Distro"
        }

        It "Should handle os-release with quoted values properly" {
            $path = $ImageRoot
            $localTarFile = "quoted-values.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction with quoted values in os-release
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "etc" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
ID="centos"
VERSION_ID="8.4"
BUILD_ID="20210507.1"
'@
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Name | Should -Be "Quoted"
            $image.Release | Should -Be "8.4"
            $image.Distribution | Should -Be "Centos"
        }

        It "Should handle os-release with only ID field" {
            $path = $ImageRoot
            $localTarFile = "minimal.release.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction with minimal os-release content
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "etc" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
ID=fedora
NAME="Fedora Linux"
'@
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Distribution | Should -Be "Fedora"
            $image.Release | Should -Be "unknown"     # Falls back to unknown when os-release parsing fails
        }

        It "Should handle alpine os-release files" {
            $path = $ImageRoot
            $localTarFile = "WellFormedAlpine.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction with minimal os-release content
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "usr" "lib" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.22.1
PRETTY_NAME="Alpine Linux v3.22"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
'@
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Distribution | Should -Be "Alpine"
            $image.Release | Should -Be "3.22.1"
            $image.Name | Should -Be "WellFormedAlpine"
        }

        It "Should handle arch os-release files" {
            $path = $ImageRoot
            $localTarFile = "WellFormedArch.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction with minimal os-release content
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "etc" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://gitlab.archlinux.org/groups/archlinux/-/issues"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=archlinux-logo
'@
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Distribution | Should -Be "Arch"
            $image.Release | Should -Be "rolling"
            $image.Name | Should -Be "WellFormedArch"
        }

        It "Should handle ubuntu os-release files" {
            $path = $ImageRoot
            $localTarFile = "WellFormedUbuntu.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction with minimal os-release content
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "etc" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
PRETTY_NAME="Ubuntu Questing Quokka (development branch)"
NAME="Ubuntu"
VERSION_ID="25.10"
VERSION="25.10 (Questing Quokka)"
VERSION_CODENAME=questing
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=questing
LOGO=ubuntu-logo
'@
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeFalse
            $image.Distribution | Should -Be "Ubuntu"
            $image.Release | Should -Be "25.10"
            $image.Name | Should -Be "WellFormedUbuntu"
        }

        It "Should handle user configured alpine os-release files" {
            $path = $ImageRoot
            $localTarFile = "WellFormedAlpine.tar.gz"
            $file = New-Item -Path $path -Name $localTarFile -ItemType File

            # Mock tar extraction with minimal os-release content
            Mock -CommandName Invoke-Tar -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Mocking tar extraction with malformed data for $($Arguments | ConvertTo-Json -Compress)"
                $destinationDirectory = $Arguments[3]
                $osReleasePath = Join-Path $destinationDirectory "etc" "os-release"
                New-Item -Path (Split-Path $osReleasePath) -ItemType Directory -Force | Out-Null
                Set-Content -Path $osReleasePath -Value @'
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.22.1
PRETTY_NAME="Alpine Linux v3.22"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
'@
                $wslConfPath = Join-Path $destinationDirectory "etc" "wsl.conf"
                Set-Content -Path $wslConfPath -Value @'
[user]
default=alpine
'@

                $passwdPath = Join-Path $destinationDirectory "etc" "passwd"
                Set-Content -Path $passwdPath -Value @'
alpine:x:1000:1000:Alpine User:/home/alpine:/bin/zsh
root:x:0:0:root:/root:/bin/ash
'@
                $wslConfiguredFile = Join-Path $destinationDirectory "etc" "wsl-configured"
                New-Item -Path $wslConfiguredFile -ItemType File -Force | Out-Null
                return ""
            }

            $image = InModuleScope -ModuleName Wsl-Manager -Parameters @{
                file = $file
            } -ScriptBlock {
                $image = Get-DistributionInformationFromFile -File $file -Verbose
                return $image
            }

            $image.Type | Should -Be "Local"
            $image.Configured | Should -BeTrue
            $image.Distribution | Should -Be "Alpine"
            $image.Release | Should -Be "3.22.1"
            $image.Name | Should -Be "WellFormedAlpine"
            $image.Username | Should -Be "alpine"
            $image.Uid | Should -Be 1000
        }


        It "Should fetch distribution information from docker image" {
            Add-DockerImageMock -Repository $TestBuiltinImageName -Tag $TestTag

            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestBuiltinImageName = $TestBuiltinImageName
                TestTag = $TestTag
            } -ScriptBlock {
                $result = Get-DistributionInformationFromDockerImage -ImageName $TestBuiltinImageName -Tag $TestTag -Verbose
                # Write-Verbose "$($result | ConvertTo-Json -Depth 5)" -Verbose
                $result.Name | Should -Be "alpine-base"
                $result.Distribution | Should -Be "Alpine"
                $result.Release | Should -Be "3.22.1"
                $result.Type | Should -Be "Builtin"
                $result.Configured | Should -Be $false

                $uri = [Uri]::new("docker://ghcr.io/$TestBuiltinImageName#$TestTag")
                $result = Get-DistributionInformationFromUri -Uri $uri -Verbose
                $result.Name | Should -Be "alpine-base"
                $result.Distribution | Should -Be "Alpine"
                $result.Release | Should -Be "3.22.1"
                $result.Type | Should -Be "Builtin"
                $result.Configured | Should -Be $false

                $uri = [Uri]::new("docker://ghcr.io/$TestBuiltinImageName")
                $result = Get-DistributionInformationFromUri -Uri $uri -Verbose
                $result.Name | Should -Be "alpine-base"
                $result.Distribution | Should -Be "Alpine"
                $result.Release | Should -Be "3.22.1"
                $result.Type | Should -Be "Builtin"
                $result.Configured | Should -Be $false

                Mock -CommandName Get-DockerImageManifest -ModuleName Wsl-Manager -MockWith {
                    throw "Docker image not found"
                }

                $result = Get-DistributionInformationFromDockerImage -ImageName "nonexistent/image" -Tag "latest" -ErrorAction SilentlyContinue
                $result | Should -Not -BeNullOrEmpty
                $result.Url | Should -Be "docker://ghcr.io/nonexistent/image#latest"
            }
            $Error[0] | Should -Not -BeNullOrEmpty
            $Error[0].Exception.Message | Should -Match "Failed to get image labels from *"

        }

        It "Should fetch distribution information from HTTP Url" {
            $TestRootFSUrl = [System.Uri]::new("https://fra1lxdmirror01.do.letsbuildthe.cloud/images/alpine/3.22/amd64/default/20250929_13%3A00/rootfs.tar.xz")
            $TestSha256Url = [System.Uri]::new($TestRootFSUrl, "SHA256SUMS")
            Add-InvokeWebRequestFixtureMock -SourceUrl $TestSha256Url.AbsoluteUri -fixtureName "SHA256SUMS-alpine-3.22.txt"
            New-InvokeWebRequestMock -SourceUrl $TestRootFSUrl.AbsoluteUri -Content "" -Headers @{ 'Content-Length' = '18879884' } -StatusCode 200
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestRootFSUrl = $TestRootFSUrl
            } -ScriptBlock {
                $result = Get-DistributionInformationFromUrl -Uri $TestRootFSUrl -Verbose
                Write-Verbose "$($result | ConvertTo-Json -Depth 5)" -Verbose
                $result.Type | Should -Be "Uri"
                $result.Name | Should -Be "alpine"
                $result.Distribution | Should -Be "Alpine"
                $result.Release | Should -Be "3.22"
                $result.FileHash | Should -Not -BeNullOrEmpty
                $result.Size | Should -Be 18879884
            }
        }

        It "Should fetch distribution information from HTTP Url with sha256 file" {
            # Try second method with sha256 file
            $TestRootFSUrl2 = [System.Uri]::new("https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.0-x86_64.tar.gz")
            New-InvokeWebRequestMock -SourceUrl "$($TestRootFSUrl2.AbsoluteUri).sha256" -Content @"
18879884e35b0718f017a50ff85b5e6568279e97233fc42822229585feb2fa4d  alpine-minirootfs-3.22.0-x86_64.tar.gz
"@
            New-InvokeWebRequestMock -SourceUrl $TestRootFSUrl2.AbsoluteUri -Content "" -Headers @{ 'Content-Length' = '18879884' } -StatusCode 200
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestRootFSUrl2 = $TestRootFSUrl2
            } -ScriptBlock {
                $result = Get-DistributionInformationFromUrl -Uri $TestRootFSUrl2 -Verbose
                Write-Verbose "$($result | ConvertTo-Json -Depth 5)" -Verbose
                $result.Type | Should -Be "Uri"
                $result.Name | Should -Be "alpine"
                $result.Distribution | Should -Be "Alpine"
                $result.Release | Should -Be "3.22.0"
                $result.FileHash | Should -Not -BeNullOrEmpty
                $result.Size | Should -Be 18879884
            }
        }

        It "Should fetch distribution information with name in path and not filename from HTTP Url with sha256 file" {
            # Try second method with sha256 file
            $TestRootFSUrl2 = [System.Uri]::new("https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.22/releases/x86_64/minirootfs-x86_64.tar.gz")
            New-InvokeWebRequestMock -SourceUrl "$($TestRootFSUrl2.AbsoluteUri).sha256" -Content @"
18879884e35b0718f017a50ff85b5e6568279e97233fc42822229585feb2fa4d  alpine-minirootfs-3.22.0-x86_64.tar.gz
"@
            New-InvokeWebRequestMock -SourceUrl $TestRootFSUrl2.AbsoluteUri -Content "" -Headers @{ 'Content-Length' = '18879884' } -StatusCode 200
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestRootFSUrl2 = $TestRootFSUrl2
            } -ScriptBlock {
                $result = Get-DistributionInformationFromUrl -Uri $TestRootFSUrl2 -Verbose
                Write-Verbose "$($result | ConvertTo-Json -Depth 5)" -Verbose
                $result.Type | Should -Be "Uri"
                $result.Name | Should -Be "alpine"
                $result.Distribution | Should -Be "Alpine"
                $result.Release | Should -Be "3.22"
                $result.FileHash | Should -Not -BeNullOrEmpty
                $result.Size | Should -Be 18879884
            }
        }

        It "Should fail when Uri is not http nor https" {
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestRootFSUrl = [System.Uri]::new("ftp://example.com/alpine-rootfs.tar.gz")
            } -ScriptBlock {
                { Get-DistributionInformationFromUrl -Uri $TestRootFSUrl -Verbose } | Should -Throw "The specified URI must use http or https scheme*"
            }
        }

        It "Should fail on URI where information cannot be determined" {
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestRootFSUrl = [System.Uri]::new("https://example.com/rootfs.tar.gz")
            } -ScriptBlock {

                { Get-DistributionInformationFromUrl -Uri $TestRootFSUrl -Verbose } | Should -Throw "Could not determine the distribution name from the URL*"
            }
        }

        It "Should retrieve a local image by URL" {
            $metadata = New-MockImage -BasePath ([WslImage]::BasePath) `
                -Name "alpine" `
                -Os "Alpine" `
                -Release "3.22.1" `
                -Type "Builtin" `
                -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine#latest" `
                -LocalFileName "alpine.rootfs.tar.gz" `
                -Configured $true `
                -Username "alpine" `
                -Uid 1000 `
                -CreateMetadata $false `
                -ErrorAction Stop `

            $TarballPath = Join-Path ([WslImage]::BasePath).FullName $metadata.LocalFileName
            $fileInfo = Get-Item $TarballPath
            $image = New-WslImageSource -File $fileInfo | Save-WslImageSource

            $image | Should -Not -BeNullOrEmpty
            $image.Id | Should -Not -Be [Guid]::Empty
            $image.Type | Should -Be "Local"
            $image.Name | Should -Be "alpine"
            $image.Url | Should -Not -BeNullOrEmpty
            $image.Url.AbsoluteUri.ToString() -match '^file://' | Should -BeTrue

            Write-Verbose "Testing Get-DistributionInformationFromUri for local://$($image.Name)#$($image.Release)" -Verbose
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                Name = $image.Name
                LocalUrl = "local://$($image.Name)#$($image.Release)"
                LocalUrlNoRelease = "local://$($image.Name)"
            } -ScriptBlock{
                $info = Get-DistributionInformationFromUri -Uri $LocalUrl
                $info | Should -Not -BeNullOrEmpty
                $info.Name | Should -Be $Name
                $info.Type | Should -Be "Local"
                $info = Get-DistributionInformationFromUri -Uri $LocalUrlNoRelease
                $info | Should -Not -BeNullOrEmpty
                $info.Name | Should -Be $Name
                $info.Type | Should -Be "Local"
            }
        }

        It "Should fail properly on bad or unhandled URI schemes" {
            InModuleScope -ModuleName Wsl-Manager -Parameters @{
                TestFtpUri = [System.Uri]::new("ftp://example.com/image.tar.gz")
                TestNonExistentFileUri = [System.Uri]::new("file://C:/nonexistent/image.tar.gz")
                TestNonExistentSchemeUri = [System.Uri]::new("unknown://example.com/image.tar.gz")
            } -ScriptBlock {
                { Get-DistributionInformationFromUri -Uri $TestFtpUri } | Should -Throw "FTP scheme is not supported yet*"
                { Get-DistributionInformationFromUri -Uri $TestNonExistentFileUri } | Should -Throw "The specified file does not exist:*"*
                { Get-DistributionInformationFromUri -Uri $TestNonExistentSchemeUri } | Should -Throw "Unsupported URI scheme*"
            }
        }
    }

    Context "Builtins" {
        It "should split Incus names" {
            $Image = New-WslImageSource -Uri "incus://almalinux#9"
            $Image.Distribution | Should -Be "almalinux"
            $Image.Release | Should -Be "9"
            $Image.Type | Should -Be "Incus"
            $Image.IsCached | Should -BeTrue
            $Image.Id | Should -Not -Be '00000000-0000-0000-0000-000000000000'

            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ModuleName Wsl-Manager
        }

        It "Should fail on bad Incus names" {
            { New-WslImageSource -Uri "incus://badlinux#9" } | Should -Throw "Unknown image with OS badlinux and Release 9 and type Incus."
        }

        It "Should Recognize Builtin images" {

            $ImageSource = New-WslImageSource -Name "alpine-base"
            $ImageSource.Distribution | Should -Be "Alpine"
            $ImageSource.Release | Should -Be $MockBuiltins[0].Release
            $ImageSource.Configured | Should -BeFalse
            $ImageSource.Type | Should -Be "Builtin"
            $ImageSource.Url | Should -Be $MockBuiltins[0].Url
            $ImageSource.Username | Should -Be "root"
            $ImageSource.Uid | Should -Be 0
            $ImageSource.Digest | Should -Be $MockBuiltins[0].Digest

            $ImageSource = New-WslImageSource -Name "alpine"
            $ImageSource.Configured | Should -BeTrue
            $ImageSource.Url | Should -Be $MockBuiltins[1].Url
            $ImageSource.Username | Should -Be "alpine"
            $ImageSource.Uid | Should -Be 1000
            $ImageSource.Digest | Should -Be $MockBuiltins[1].Digest
        }

        It "Should update builtin image cache" {
            $root = $ImageRoot

            try {
                Write-Test "First update call - should update cache"
                $updated = Update-WslBuiltinImageCache
                Write-Test "First update call completed. updated = $updated"
                $updated | Should -BeTrue

                $builtinsFile = [WslImageDatabase]::DatabaseFileName.FullName
                $builtinsFile | Should -Exist
                $db = InModuleScope -ModuleName Wsl-Manager {
                    param($builtinsFile)
                    Write-Test "Opening $builtinsFile"
                    $db = [SQLiteHelper]::Open($builtinsFile)
                    return $db
                } -ArgumentList @($builtinsFile)
                $dt = $db.ExecuteSingleQuery("SELECT * from ImageSourceCache")
                $dt | Should -Not -BeNullOrEmpty
                $dt.Rows.Count | Should -Be 1
                $firstLastUpdate = $dt.Rows[0].LastUpdate
                $dt.Rows | ForEach-Object {
                    $_.Url | Should -Be $global:builtinsSourceUrl
                    $_.LastUpdate | Should -BeGreaterThan 0
                    $_.Etag | Should -Be "MockedTag"
                }

                # Calling again should not update cache (within 24h)
                Write-Test "Second update call - cache should be valid"
                $updated = Update-WslBuiltinImageCache
                $updated | Should -BeFalse

                Should -Invoke -CommandName Invoke-WebRequest -Times 0 -ParameterFilter {
                    $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
                } -ModuleName Wsl-Manager

                # Force sync should update
                Write-Test "Force sync call"
                Start-Sleep -Seconds 1
                $updated = Update-WslBuiltinImageCache -Sync
                $updated | Should -BeFalse # 304 response means no update needed

                Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ParameterFilter {
                    $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
                } -ModuleName Wsl-Manager

                # Force lastUpdate to yesterday to trigger a refresh
                $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
                $NewLastUpdate = $currentTime - 86410
                $db.ExecuteNonQuery("UPDATE ImageSourceCache SET LastUpdate=:NewLastUpdate;", @{
                    NewLastUpdate = $NewLastUpdate
                })

                Write-Test "Update call one day later without changes"
                $updated = Update-WslBuiltinImageCache
                $updated | Should -BeFalse # 304 response

                Should -Invoke -CommandName Invoke-WebRequest -Times 2 -ParameterFilter {
                    $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
                } -ModuleName Wsl-Manager

                # Test that lastUpdate is newer after 304 response
                $dt = $db.ExecuteSingleQuery("SELECT * from ImageSourceCache")
                $dt.Rows[0].LastUpdate | Should -BeGreaterThan $firstLastUpdate

                # Set up for content change test
                $NewLastUpdate = $currentTime - 86410
                $db.ExecuteNonQuery("UPDATE ImageSourceCache SET LastUpdate=:NewLastUpdate;", @{
                    NewLastUpdate = $NewLastUpdate
                })
                New-BuiltinSourceMock -Tag $MockModifiedETag

                Write-Test "Update call one day later with changes (new etag)"
                $updated = Update-WslBuiltinImageCache
                $updated | Should -BeTrue

                Should -Invoke -CommandName Invoke-WebRequest -Times 2 -ParameterFilter {
                    $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
                } -ModuleName Wsl-Manager

                $dt = $db.ExecuteSingleQuery("SELECT * from ImageSourceCache")
                $dt.Rows | ForEach-Object {
                    $_.LastUpdate | Should -BeGreaterThan $firstLastUpdate -Because "Cache was refreshed so the lastUpdate should be greater."
                    $_.Etag | Should -Be "NewMockedTag"
                }
            } finally {
                if ($null -ne $db -and $db.IsOpen) {
                    $db.Close()
                }
            }
        }

        It "Should get builtin images from cache and database" {
            Write-Test "First call - should update cache and get images"
            $images = Get-WslImageSource
            $images | Should -Not -BeNullOrEmpty
            $images.Count | Should -Be $MockBuiltins.Count

            # Verify database was populated
            $builtinsFile = [WslImageDatabase]::DatabaseFileName.FullName
            $builtinsFile | Should -Exist

            Write-Test "Second call - should use cached data"
            $images = Get-WslImageSource
            $images | Should -Not -BeNullOrEmpty
            $images.Count | Should -Be $MockBuiltins.Count

            # Should not make additional web requests for cached data
            Should -Invoke -CommandName Invoke-WebRequest -Times 0 -ParameterFilter {
                $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
            } -ModuleName Wsl-Manager

            Write-Test "Force sync call"
            $images = Get-WslImageSource -Sync
            $images | Should -Not -BeNullOrEmpty
            $images.Count | Should -Be $MockBuiltins.Count

            # Should make one web request with ETag
            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ParameterFilter {
                $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
            } -ModuleName Wsl-Manager
        }

        It "should fail nicely on builtin images retrieval" {
            Write-Test "Web exception in Get-WslImageSource"
            Mock Invoke-WebRequest { throw [System.Net.WebException]::new("test", 7) } -ModuleName Wsl-Manager -Verifiable -ParameterFilter {
                return $true
            }

            { Update-WslBuiltinImageCache } | Should -Throw "The response content from *"

            Write-Test "JSON parsing exception in Get-WslImageSource"
            Mock Invoke-WebRequest {
                $Response = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
                $Response | Add-Member -MemberType NoteProperty -Name StatusCode -Value 200 -Force
                $ResponseHeaders = @{
                    'Content-Type' = 'application/json; charset=utf-8'
                }
                $Response | Add-Member -MemberType NoteProperty -Name Headers -Value $ResponseHeaders -Force
                $Response | Add-Member -MemberType NoteProperty -Name Content -Value "This is bad json" -Force
                return $Response
            } -ModuleName Wsl-Manager -Verifiable -ParameterFilter {
                return $true
            }

            $images = Get-WslImageSource -ErrorAction SilentlyContinue
            $images | Should -BeNullOrEmpty
            $Error[0] | Should -Not -BeNullOrEmpty
            $Error[0].Exception.Message | Should -Match "Conversion from JSON failed with error*"
        }

        It "Should download and cache incus images" {
            try {
                $root =  $ImageRoot
                Write-Test "First call"
                $images = Get-WslImageSource -Type Incus
                $images | Should -Not -BeNullOrEmpty
                $images.Count | Should -Be $MockIncus.Count

                $builtinsFile = [WslImageDatabase]::DatabaseFileName.FullName
                $builtinsFile | Should -Exist
                $db = InModuleScope -ModuleName Wsl-Manager {
                    param($builtinsFile)
                    [SQLiteHelper]::Open($builtinsFile)
                } -ArgumentList @($builtinsFile)

                $dt = $db.ExecuteSingleQuery("SELECT * from ImageSourceCache")
                $dt.Rows | Should -Not -BeNullOrEmpty
                $dt.Rows.Count | Should -Be 1
                $dt.Rows | ForEach-Object {
                    $_.Url | Should -Be $global:incusSourceUrl
                    $_.LastUpdate | Should -BeGreaterThan 0
                    $_.Etag | Should -Be "MockedTag"
                }
            } finally {
                if ($null -ne $db -and $db.IsOpen) {
                    $db.Close()
                }
            }
        }

        It "Should not update cache for other types" {
            $result = Update-WslBuiltinImageCache -Type Uri
            $result | Should -BeFalse
        }

        It "Should filter images sources" {
            $sources = Get-WslImageSource -Source All
            $sources.Count | Should -Be ($MockBuiltins.Count + $MockIncus.Count)

            $sources = Get-WslImageSource -Configured
            $sources.Count | Should -Be ($MockBuiltins | Where-Object { $_.Configured }).Count

            $sources = Get-WslImageSource -Distribution Alpine
            $sources.Count | Should -Be 2

            $sources = Get-WslImageSource -Name alp*
            $sources.Count | Should -Be 2
            $sources[0].Tags | Should -Contain "latest"

            $sources = Get-WslImageSource -Name alp* -Source All
            $sources.Count | Should -Be 4

            Mock Update-WslBuiltinImageCache -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Fail update cache with WslManagerException"
                InModuleScope Wsl-Manager {
                    throw [WslManagerException]::new("Cache update failed")
                }
            }
            { Get-WslImageSource -Source All } | Should -Throw "Cache update failed"
            Mock Update-WslBuiltinImageCache -ModuleName Wsl-Manager -MockWith {
                Write-Mock "Fail update cache with other exception"
                throw "Cache update failed"
            }
            Get-WslImageSource -Source All -ErrorAction SilentlyContinue | Should -BeFalse
            $Error[0] | Should -Not -BeNullOrEmpty
            $Error[0].Exception.Message | Should -Match "Cache update failed"
        }
    }

    Context "Cmdlets" {
        It "Should find and incus image from a name composed of a image name and version" {
            $path = $ImageRoot
            $ImageName = "incus://alpine#3.19"
            Write-Test "Testing image name: $ImageName"

            $imageSource = New-WslImageSource -Uri $ImageName
            Write-Test "Image: $($imageSource.Url)"
            $imageSource | Should -Not -BeNullOrEmpty
            $imageSource.Type | Should -Be "Incus"

            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
                $PesterBoundParameters.Uri -eq $global:incusSourceUrl
            }

            $mockImage = New-ImageFromMock -Mock $AlternateMock

            $imageSource.Digest = $mockImage.FileHash
            $image = New-WslImage -Source $imageSource

            $image | Should -Not -BeNullOrEmpty
            $image.IsAvailableLocally | Should -BeTrue
            $image.State | Should -Be "Synced"
            $image.Type | Should -Be "Incus"
        }

        It "Should instantiate image source from builtin information" {
            $imageSource = [WslImageSource]::new($TestMock)
            $imageSource | Should -Not -BeNullOrEmpty
            $imageSource.Type | Should -Be $TestMock.Type
            $imageSource.Url | Should -Be $TestMock.Url
            $imageSource.Id | Should -Not -BeNullOrEmpty
            $imageSource.Id.ToString() | Should -Be '00000000-0000-0000-0000-000000000000'

            $alternateSource = [WslImageSource]::new($AlternateMock)
            $alternateSource | Should -Not -BeNullOrEmpty
            $alternateSource.Type | Should -Be $AlternateMock.Type
            $alternateSource.Url | Should -Be $AlternateMock.Url
            $alternateSource.Id | Should -Not -BeNullOrEmpty
            $alternateSource.Id.ToString() | Should -Be '00000000-0000-0000-0000-000000000000'

            $imageSource.CompareTo($alternateSource) | Should -Be 1

            $sourceObject = $imageSource.ToObject()
            $newSource = [WslImageSource]::new($sourceObject)
            $newSource | Should -Not -BeNullOrEmpty
            $newSource.Type | Should -Be $imageSource.Type
            $newSource.Url | Should -Be $imageSource.Url
            $newSource.Id | Should -Be $imageSource.Id

            $sourceObject.Url = $null
            { [WslImageSource]::new($sourceObject) } | Should -Throw "Invalid image source configuration for arch: *"
        }

        It "Should create an image source from a file path by name" {
            $metadata = New-MockImage -BasePath ([WslImage]::BasePath) `
                -Name "alpine" `
                -Os "Alpine" `
                -Release "3.22.1" `
                -Type "Builtin" `
                -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine#latest" `
                -LocalFileName "alpine.rootfs.tar.gz" `
                -Configured $true `
                -Username "alpine" `
                -Uid 1000 `
                -CreateMetadata $false `
                -ErrorAction Stop `

            $TarballPath = Join-Path ([WslImage]::BasePath).FullName $metadata.LocalFileName
            $imageSource = New-WslImageSource -Name $TarballPath

            $imageSource.Type | Should -Be "Local"
            $imageSource.Url | Should -Not -BeNullOrEmpty
            $imageSource.Url.AbsoluteUri.ToString() -match '^file://' | Should -BeTrue
        }
    }
}
