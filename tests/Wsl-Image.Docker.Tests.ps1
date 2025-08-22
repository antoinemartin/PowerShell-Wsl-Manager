using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
Param()

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module "$PSScriptRoot/TestAssertions.psm1" -DisableNameChecking
}


BeforeAll {
    Import-Module Wsl-Manager
    Import-Module $PSScriptRoot\TestUtils.psm1 -Force
}

Describe 'WslImage.Docker' {
    BeforeAll {
        # Create a temporary WSL root for testing
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "RootFS"
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()

        $TestImageName = "antoinemartin/powershell-wsl-manager/alpine-base"
        $TestTag = "latest"

        # Mock builtins and Incus sources
        New-BuiltinSourceMock
        New-IncusSourceMock

        # Set-MockPreference $true

        function Get-DockerAuthTokenUrl($Repository) {
            return "https://ghcr.io/token?service=ghcr.io&scope=repository:$($Repository):pull"
        }
        function Get-DockerIndexUrl($Repository, $Tag) {
            return "https://ghcr.io/v2/$Repository/manifests/$Tag"
        }
        function Get-DockerBlobUrl($Repository, $Digest) {
            $result = "https://ghcr.io/v2/$Repository/blobs/$Digest"
            return $result
        }
        function Get-DockerManifestUrl($Repository, $Digest) {
            return "https://ghcr.io/v2/$Repository/manifests/$Digest"
        }
        function Get-FixtureFilename($Repository, $Tag, $Suffix) {
            $safeRepo = $Repository -replace '[\/:]', '_slash_'
            return "docker_$($safeRepo)_colon_$($Tag)_$Suffix.json"
        }

        function Add-DockerImageMock($Repository, $Tag) {
            $authFixture = Get-FixtureFilename $Repository $Tag "token"
            $indexFixture = Get-FixtureFilename $Repository $Tag "index"
            $manifestFixture = Get-FixtureFilename $Repository $Tag "manifest"
            $configFixture = Get-FixtureFilename $Repository $Tag "config"

            $index = Get-FixtureContent $indexFixture | ConvertFrom-Json
            $manifestDigest = ($index.manifests | Where-Object { $_.platform.architecture -eq 'amd64' }).digest

            $manifest = Get-FixtureContent $manifestFixture | ConvertFrom-Json
            $configDigest = $manifest.config.digest

            $authUrl = Get-DockerAuthTokenUrl $Repository
            $indexUrl = Get-DockerIndexUrl $Repository $Tag
            $manifestUrl = Get-DockerManifestUrl $Repository $manifestDigest
            $configUrl = Get-DockerBlobUrl $Repository $configDigest

            Add-InvokeWebRequestFixtureMock -SourceUrl $authUrl -FixtureName $authFixture | Out-Null
            Add-InvokeWebRequestFixtureMock -SourceUrl $indexUrl -FixtureName $indexFixture -Headers @{ "Content-Type" = "application/vnd.docker.distribution.manifest.list.v2+json" } | Out-Null
            Add-InvokeWebRequestFixtureMock -SourceUrl $manifestUrl -FixtureName $manifestFixture -Headers @{ "Content-Type" = "application/vnd.docker.distribution.manifest.v2+json" } | Out-Null
            Add-InvokeWebRequestFixtureMock -SourceUrl $configUrl -FixtureName $configFixture -Headers @{ "Content-Type" = "application/vnd.docker.distribution.config.v1+json" } | Out-Null
            return $manifest.layers[0].digest
        }
    }

    It "should download docker image manifest" {
        Add-DockerImageMock -Repository $TestImageName -Tag $TestTag

        InModuleScope -ModuleName Wsl-Manager -Parameters @{
            TestImageName = $TestImageName
            TestTag = $TestTag
        } -ScriptBlock {
            Write-Test "Testing Get-DockerImageManifest for $($TestImageName):$TestTag"
            $manifest = Get-DockerImageManifest -ImageName $TestImageName -Tag $TestTag
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

    It "should download docker image" {
        $ImageDigest = Add-DockerImageMock -Repository $TestImageName -Tag $TestTag
        $Url = Get-DockerBlobUrl $TestImageName $ImageDigest

        $DestinationFile = Join-Path $ImageRoot "docker.alpine-base.tar.gz"

        InModuleScope -ModuleName Wsl-Manager -Parameters @{
            TestImageName = $TestImageName
            TestTag = $TestTag
            ImageDigest = $imageDigest
            BlobUrl = $Url
            DestinationFile = $DestinationFile
        } -ScriptBlock {
            Mock Start-Download -Verifiable -ParameterFilter { $Url -eq $BlobUrl } -MockWith {
                param ($Url, $to, $Headers)
                New-Item -Path $to -ItemType File -Value "Dummy content for $($TestImageName):$($TestTag)" | Out-Null
            }

            Write-Test "Testing Get-DockerImage -ImageName $($TestImageName) -Tag $($TestTag) (digest $ImageDigest)"
            $expectedHash = Get-DockerImage -ImageName $TestImageName -Tag $TestTag -DestinationFile $DestinationFile
            $expectedHash | Should -Be ($ImageDigest -split ':')[1]
            Should -Invoke Invoke-WebRequest -Times 4 -ModuleName Wsl-Manager
            Should -Invoke Start-Download -Times 1 -ModuleName Wsl-Manager -ParameterFilter {
                $Url -eq $BlobUrl
            }
        }
    }
}
