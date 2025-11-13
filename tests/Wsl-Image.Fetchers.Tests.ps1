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

            $info = Get-DistributionInformationFromName -Name "justaname"
            $info.Name | Should -Be "justaname"
            $info.ContainsKey("Release") | Should -Be $false
            $info.ContainsKey("Type") | Should -Be $false
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
