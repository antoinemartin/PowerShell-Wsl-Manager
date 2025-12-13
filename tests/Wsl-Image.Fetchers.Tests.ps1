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

Describe "WslImage.Fetchers"  {
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
            # Write-Verbose "$($result | ConvertTo-Json -Depth 5)" -Verbose
            $result.Name | Should -Be "alpine-base"
            $result.Distribution | Should -Be "Alpine"
            $result.Release | Should -Be "3.22.1"
            $result.Type | Should -Be "Builtin"
            $result.Configured | Should -Be $false

        }

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

}
