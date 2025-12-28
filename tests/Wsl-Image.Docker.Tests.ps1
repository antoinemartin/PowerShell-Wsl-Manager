using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param()

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
}


BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    Import-Module (Join-Path $PSScriptRoot "TestUtils.psm1") -Force
}

Describe 'WslImage.Docker' {
    BeforeAll {
        # Create a temporary WSL root for testing
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

        # Mock builtins and Incus sources
        New-BuiltinSourceMock
        New-IncusSourceMock

        Set-MockPreference ($true -eq $Global:PesterShowMock)
    }

    AfterEach {
        InModuleScope -ModuleName Wsl-Manager {
            Close-WslImageDatabase
        }
        Get-ChildItem -Path ([WslImage]::BasePath).FullName | Remove-Item -Force
    }

    It "should download docker image manifest" {
        Add-DockerImageMock -Repository $TestBuiltinImageName -Tag $TestTag

        InModuleScope -ModuleName Wsl-Manager -Parameters @{
            TestBuiltinImageName = $TestBuiltinImageName
            TestTag = $TestTag
        } -ScriptBlock {
            Write-Test "Testing Get-DockerImageManifest for $($TestBuiltinImageName):$TestTag"
            $manifest = Get-DockerImageManifest -ImageName $TestBuiltinImageName -Tag $TestTag
            $manifest | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -Times 4 -ModuleName Wsl-Manager
            # Write-Host ($manifest | ConvertTo-Json -Depth 10)
            $manifest.os | Should -Be 'linux'
            $manifest.architecture | Should -Be 'amd64'
            $manifest.size | Should -BeGreaterThan 0
            $manifest.config.Labels['org.opencontainers.image.source'] | Should -Be 'https://github.com/antoinemartin/powershell-wsl-manager'
            $manifest.config.Labels['org.opencontainers.image.flavor'] | Should -Be 'alpine'
            $manifest.config.Labels['org.opencontainers.image.version'] | Should -Be '3.22.1'
        }
    }

    It "should download image manifest from docker hub" {
        Add-DockerImageMock -Repository $TestDockerHubImageName -Tag $TestTag -Registry $DockerHubRegistryDomain
        InModuleScope -ModuleName Wsl-Manager -Parameters @{
            TestDockerHubImageName = $TestDockerHubImageName
            TestTag = $TestTag
        } -ScriptBlock {
            Write-Test "Testing Get-DockerImageManifest for $($TestDockerHubImageName):$TestTag"
            $manifest = Get-DockerImageManifest -ImageName $TestDockerHubImageName -Tag $TestTag -Registry "docker.io"
            $manifest | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -Times 4 -ModuleName Wsl-Manager
            $manifest.os | Should -Be 'linux'
            $manifest.architecture | Should -Be 'amd64'
            $manifest.size | Should -BeGreaterThan 0

            $otherImageName = $TestDockerHubImageName -replace "library/", ""
            Write-Test "Testing Get-DockerImageManifest for $($otherImageName):$TestTag"
            $manifest = Get-DockerImageManifest -ImageName $otherImageName -Tag $TestTag -Registry "docker.io"
            $manifest | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-WebRequest -Times 8 -ModuleName Wsl-Manager
            $manifest.os | Should -Be 'linux'
            $manifest.architecture | Should -Be 'amd64'
            $manifest.size | Should -BeGreaterThan 0

            $token = Get-DockerAuthToken -Registry "docker.io" -Repository $otherImageName
            $token | Should -Not -BeNullOrEmpty
        }
    }

    It "should download docker image" {
        $ImageDigest = Add-DockerImageMock -Repository $TestBuiltinImageName -Tag $TestTag
        $Url = Get-DockerBlobUrl $TestBuiltinImageName $ImageDigest

        $DestinationFile = Join-Path $ImageRoot "docker.alpine-base.tar.gz"

        InModuleScope -ModuleName Wsl-Manager -Parameters @{
            TestBuiltinImageName = $TestBuiltinImageName
            TestTag = $TestTag
            ImageDigest = $imageDigest
            BlobUrl = $Url
            DestinationFile = $DestinationFile
        } -ScriptBlock {
            Mock Start-Download -Verifiable -ParameterFilter { $Url -eq $BlobUrl } -MockWith {
                param ($Url, $to, $Headers)
                New-Item -Path $to -ItemType File -Value "Dummy content for $($TestBuiltinImageName):$($TestTag)" | Out-Null
            }

            Write-Test "Testing Get-DockerImage -ImageName $($TestBuiltinImageName) -Tag $($TestTag) (digest $ImageDigest)"
            $expectedHash = Get-DockerImage -ImageName $TestBuiltinImageName -Tag $TestTag -DestinationFile $DestinationFile
            $expectedHash | Should -Be ($ImageDigest -split ':')[1]
            Should -Invoke Invoke-WebRequest -Times 4 -ModuleName Wsl-Manager
            Should -Invoke Start-Download -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
                $Url -eq $BlobUrl
            }
        }
    }

    It "Should create the builtin image from the appropriate docker URL" {
        $ImageDigest = Add-DockerImageMock -Repository $TestBuiltinImageName -Tag $TestTag

        Update-WslBuiltinImageCache -Type Builtin -Verbose | Out-Null

        $image = New-WslImage -Name "docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine-base#latest" -Verbose
        $image | Should -Not -BeNullOrEmpty
        $image.Type | Should -Be "Builtin"
        $image.Source | Should -Not -BeNullOrEmpty

        # Check that the builtins Url is called
        Should -Invoke Invoke-WebRequest -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
            $PesterBoundParameters.Uri -eq $global:builtinsSourceUrl
        }
    }

    It "Should save the WslImageSource" {
        $ImageDigest = Add-DockerImageMock -Repository $TestExternalImageName -Tag $TestTag
        $url = "docker://ghcr.io/$TestExternalImageName#$TestTag"

        $image = New-WslImageSource -Name $url  -Verbose
        $image | Should -Not -BeNullOrEmpty

        $image.Name | Should -Be "yawsldocker-alpine"
        $image.Release | Should -Be "3.22.1"
        $image.Type | Should -Be "Docker"
        $image.Distribution | Should -Be "alpine"
        $image.Id | Should -Be '00000000-0000-0000-0000-000000000000'

        # Check that the builtins Url is called
        Should -Invoke Invoke-WebRequest -Times 4 -ModuleName Wsl-Manager

        Save-WslImageSource -ImageSource $image -Verbose
        $image.Id | Should -Not -Be '00000000-0000-0000-0000-000000000000'
        $db = [WslImageDatabase]::new()
        try {
            $db.Open()
            $savedImageSource = $db.GetImageSources("Id = @Id", @{ Id = $image.Id.ToString() }) | Select-Object -First 1
            $savedImageSource | Should -Not -BeNullOrEmpty
            $savedImageSource.Name | Should -Be $image.Name
            $savedImageSource.Release | Should -Be $image.Release
        } finally {
            $db.Close()
        }

        Write-Verbose "Create a new source with same url to force update"
        $otherImage = New-WslImageSource -Uri $url -Sync -Verbose
        $otherImage.Id | Should -Be $image.Id
        Should -Invoke Invoke-WebRequest -Times 8 -ModuleName Wsl-Manager
        $otherImage.UpdateDate | Should -BeGreaterThan $image.UpdateDate

        $removed = Remove-WslImageSource -ImageSource $image -Verbose
        $removed.IsCached | Should -BeFalse
        try {
            $db.Open()
            $savedImageSource = $db.GetImageSources("Id = @Id", @{ Id = $image.Id.ToString() })
            $savedImageSource | Should -BeNullOrEmpty
        } finally {
            $db.Close()
        }
        Remove-WslImageSource -ImageSource $removed | Should -BeNullOrEmpty
        Save-WslImageSource -ImageSource $removed
        $removed.Id | Should -Not -Be '00000000-0000-0000-0000-000000000000'
        $removed = Remove-WslImageSource -Name "yawsldocker-alpine" -Type Docker
        $removed | Should -Not -BeNullOrEmpty
        Save-WslImageSource -ImageSource $removed
        $removed.Id | Should -Not -Be '00000000-0000-0000-0000-000000000000'
        $removed = Remove-WslImageSource -Id $removed.Id
        $removed | Should -Not -BeNullOrEmpty
    }

    It "Should fetch information about external docker images" {
        $ImageDigest = Add-DockerImageMock -Repository $TestExternalImageName -Tag $TestTag

        $image = New-WslImage -Name "docker://ghcr.io/$TestExternalImageName#$TestTag" -Verbose
        $image | Should -Not -BeNullOrEmpty

        $image.Name | Should -Be "yawsldocker-alpine"
        $image.Release | Should -Be "3.22.1"
        $image.Distribution | Should -Be "alpine"

        # Check that the builtins Url is called
        Should -Invoke Invoke-WebRequest -Times 4 -ModuleName Wsl-Manager
    }

    It "Should fail gracefully when unauthorized" {
        Add-DockerImageFailureMock -Repository $TestExternalImageName -Tag $TestTag -StatusCode 401 -Message "Unauthorized"
        { New-WslImage -Name "docker://ghcr.io/$TestExternalImageName#$TestTag" } | Should -Throw "Access denied to registry*"
    }

    It "Should fail gracefully when not found" {
        Add-DockerImageFailureMock -Repository $TestExternalImageName -Tag $TestTag -StatusCode 404 -Message "Not Found"
        { New-WslImage -Name "docker://ghcr.io/$TestExternalImageName#$TestTag" } | Should -Throw "Image not found:*"
    }

    It "Should fail gracefully when registry is unreachable" {
        Add-DockerImageFailureMock -Repository $TestExternalImageName -Tag $TestTag -StatusCode 500 -Message "Internal Server Error"
        { New-WslImage -Name "docker://ghcr.io/$TestExternalImageName#$TestTag" } | Should -Throw "Failed to get manifest:*"
    }

    It "Should fail gracefully when auth token cannot be retrieved" {
        $authUrl = Get-DockerAuthTokenUrl -Repository $TestExternalImageName -Tag $TestTag
        $StatusCode = 500
        Add-InvokeWebRequestErrorMock -SourceUrl $authUrl -StatusCode $StatusCode -Message "Mocked $StatusCode error for $($TestExternalImageName):$TestTag" | Out-Null

        { New-WslImage -Name "docker://ghcr.io/$TestExternalImageName#$TestTag" } | Should -Throw "Failed to get authentication token:*"
    }
}
