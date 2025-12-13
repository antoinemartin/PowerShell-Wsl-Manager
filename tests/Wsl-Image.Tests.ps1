using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification='This is a test file, global variables are used to share fixtures across tests.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification="Mock functions don't need ShouldProcess")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
Param()


BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
}


BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    Import-Module -Name (Join-Path $PSScriptRoot "TestUtils.psm1") -Force

    Set-MockPreference ($true -eq $Global:PesterShowMock)

    # Define a global constant for the empty hash
    $TestFilename = 'docker.arch.rootfs.tar.gz'
    $TestMock = $MockBuiltins[3]
    $DigestTestFilename = $TestMock.LocalFilename
    $AlternateFilename = 'incus.alpine_3.19.rootfs.tar.gz'
    $AlternateMock = $MockIncus[2]
    $DigestAlternateFilename = $AlternateMock.LocalFilename
}

Describe "WslImage" {
    BeforeAll {
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "RootFS"
        $EmptyHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
        [WslImageDatabase]::DatabaseFileName = [FileInfo]::new((Join-Path $ImageRoot "images.db"))

        InModuleScope -ModuleName Wsl-Manager {
            $global:builtinsSourceUrl = $WslImageSources[[WslImageType]::Builtin]
            $global:incusSourceUrl = $WslImageSources[[WslImageType]::Incus]
        }
        New-BuiltinSourceMock
        New-IncusSourceMock

        function Test-ImageInDatabase {
            param (
                [WslImage] $Image
            )
            $db = [WslImageDatabase]::new()
            try {
                $db.Open()
                $savedImage = $db.GetLocalImages("Id = @Id", @{ Id = $Image.Id.ToString() }) | Select-Object -First 1
                $savedImage | Should -Not -BeNullOrEmpty
                $savedImage.Name | Should -Be $Image.Name
                $savedImage.Release | Should -Be $Image.Release

                $source = $db.GetImageSources("Id = @Id", @{ Id = $Image.Source.Id.ToString() }) | Select-Object -First 1
                $source | Should -Not -BeNullOrEmpty
                $source.Url | Should -Be $Image.Url
                $source.Type | Should -Be $Image.Type.ToString()
                # Add Source to savedImage for further checks
                $savedImage | Add-Member -MemberType NoteProperty -Name Source -Value $source -Force

                return $savedImage
            } finally {
                $db.Close()
            }
        }

        function New-ImageFromMock {
            param (
                [PSCustomObject] $Mock
            )
            return New-MockImage -BasePath $ImageRoot `
                -Name $Mock.Name `
                -Os $Mock.Os `
                -Release $Mock.Release `
                -Type $Mock.Type `
                -Url $Mock.Url `
                -LocalFileName $Mock.LocalFilename `
                -Configured $Mock.Configured `
                -Username $Mock.Username `
                -Uid $Mock.Uid `
                -CreateMetadata $false `
                -ErrorAction Stop
        }
    }
    BeforeEach {
        New-GetDockerImageMock
    }
    AfterEach {
        InModuleScope -ModuleName Wsl-Manager {
            Close-WslImageDatabase
        }
        Get-ChildItem -Path ([WslImage]::BasePath).FullName | Remove-Item -Force
    }

    It "should split Incus names" {
        $Image = New-WslImage -Uri "incus://almalinux#9"
        $Image.Os | Should -Be "almalinux"
        $Image.Release | Should -Be "9"
        $Image.Type | Should -Be "Incus"
        $Image.IsCached | Should -BeTrue
        $Image.Id | Should -Not -Be '00000000-0000-0000-0000-000000000000'

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ModuleName Wsl-Manager

        $null = Test-ImageInDatabase -Image $Image
    }

    It "Should fail on bad Incus names" {
        { New-WslImage -Uri "incus://badlinux#9" } | Should -Throw "Unknown image with OS badlinux and Release 9 and type Incus."
    }

    It "Should Recognize Builtin images" {

        $Image = New-WslImage -Name "alpine-base"
        $Image.Os | Should -Be "Alpine"
        $Image.Release | Should -Be $MockBuiltins[0].Release
        $Image.Configured | Should -BeFalse
        $Image.Type | Should -Be "Builtin"
        $Image.Url | Should -Be $MockBuiltins[0].Url
        $Image.Username | Should -Be "root"
        $Image.Uid | Should -Be 0
        $Image.FileHash | Should -Be $MockBuiltins[0].Digest

        $Image = New-WslImage -Name "alpine"
        $Image.Configured | Should -BeTrue
        $Image.Url | Should -Be $MockBuiltins[1].Url
        $Image.Username | Should -Be "alpine"
        $Image.Uid | Should -Be 1000
        $Image.FileHash | Should -Be $MockBuiltins[1].Digest
    }

    It "Should split properly external URL" {
        $url = "https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-nano-amd64.tar.xz"
        $Image = New-WslImage -Name $url
        $Image.Os | Should -Be "Kali"
        $Image.Release | Should -Be "netHunter-nano"
        $Image.Configured | Should -BeFalse
        $Image.Type | Should -Be "Uri"
        $Image.Url | Should -Be $url

        $null = Test-ImageInDatabase -Image $Image
    }

    It "Should download builtin image" {

        Mock Sync-File { Write-Mock "download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File } -ModuleName Wsl-Manager
        $Image = New-WslImage -Name "alpine"
        $Image.Os | Should -Be "Alpine"
        $Image.Release | Should -Be $MockBuiltins[1].Release
        $Image.Configured | Should -BeTrue
        $Image.Type | Should -Be "Builtin"
        $Image.IsAvailableLocally | Should -BeFalse
        $Image | Sync-WslImage
        $Image.IsAvailableLocally | Should -BeTrue
        $Image.LocalFileName | Should -Be $MockBuiltins[1].LocalFilename
        $Image.File.Exists | Should -BeTrue
        Should -Invoke -CommandName Get-DockerImage -Times 1 -ModuleName Wsl-Manager

        $saved = Test-ImageInDatabase -Image $Image
        $saved.Digest | Should -Be $Image.FileHash
    }

    It "Should download image by URL" {

        Mock Get-DockerImage { throw  [System.Net.WebException]::new("test", 7) }  -ModuleName Wsl-Manager

        Mock Sync-File { Write-Mock "download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File } -ModuleName Wsl-Manager

        $TestRootFSUrl = [System.Uri]::new("https://github.com/kaweezle/iknite/releases/download/v0.5.2/kaweezle.rootfs.tar.gz")
        $TestSha256Url = [System.Uri]::new($TestRootFSUrl, "SHA256SUMS")
        $sha256Content = @"
$EmptyHash  kaweezle.rootfs.tar.gz
"@
        New-InvokeWebRequestMock -SourceUrl $TestSha256Url.AbsoluteUri -Content $sha256Content -Headers @{ 'Content-Length' = ($sha256Content.Length) } -StatusCode 200
        # This one is to mock the HEAD request to get content length
        New-InvokeWebRequestMock -SourceUrl $TestRootFSUrl.AbsoluteUri -Content "" -Headers @{ 'Content-Length' = '18879884' } -StatusCode 200

        $Image = New-WslImage -Uri $TestRootFSUrl
        $Image.Release | Should -Be "0.5.2"
        $Image.Os | Should -Be "Kaweezle"
        $Image.Configured | Should -BeFalse
        $Image.Type | Should -Be "Uri"
        $Image.IsAvailableLocally | Should -BeFalse
        $Image | Sync-WslImage
        $Image.IsAvailableLocally | Should -BeTrue
        $Image.LocalFileName | Should -Be "$($EmptyHash.ToUpper()).rootfs.tar.gz"
        $Image.File.Exists | Should -BeTrue
        Should -Invoke -CommandName Sync-File -Times 1 -ModuleName Wsl-Manager

        $saved = Test-ImageInDatabase -Image $Image
        $saved.Digest | Should -Be $Image.FileHash

        # Will fail because of exception thrown by Mock Get-DockerImage
        $Image = New-WslImage -Name "alpine"
        { $Image | Sync-WslImage } | Should -Throw "Error while loading distro *"
    }

    # FIXME: This test does not work for OCI image based images
    It "Shouldn't download already present file" {
        $path = [WslImage]::BasePath.FullName
        $digest = $TestMock.Digest
        New-Item -Path $path -Name $TestMock.LocalFilename -ItemType File
        Mock Get-DockerImageManifest { return @{
            digest = "sha256:$($digest)"
        } }  -ModuleName Wsl-Manager


        $Image = New-WslImage -Name "arch"
        Write-Test "Image Local File: $($Image.File.FullName), Digest: $digest"
        $Image.IsAvailableLocally | Should -BeTrue
        $Image.FileHash | Should -Be $digest
        $Image | Sync-WslImage
        Should -Invoke -CommandName Get-DockerImage -Times 0 -ModuleName Wsl-Manager
    }

    It "Should create image from local file" {

        New-MockImage -BasePath $TestDrive `
            -Name "arch" `
            -Os "Arch" `
            -Release "2O251201" `
            -Type "Builtin" `
            -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/arch#latest" `
            -LocalFileName $TestFilename `
            -Configured $true `
            -Username "arch" `
            -Uid 1000 `
            -CreateMetadata $false `
            -ErrorAction Stop


        $file = Get-Item -Path (Join-Path $TestDrive $TestFilename)
        $fileSystem = New-WslImage -File $file
        $fileSystem | Should -BeOfType [WslImage]
        $fileSystem.Name | Should -Be "arch"
        $fileSystem.Release | Should -Be "2O251201"
        $fileSystem.Configured | Should -BeTrue
        $fileSystem.Source | Should -Not -BeNullOrEmpty

        # Check that the image source is created in the database
        $saved = Test-ImageInDatabase -Image $fileSystem
        $saved.Source | Should -Not -BeNullOrEmpty

    }

    It "Should return local images" {
        $path = $ImageRoot

        $mockImage = New-ImageFromMock -Mock $TestMock
        $alternateMockImage = New-ImageFromMock -Mock $AlternateMock

        $imagesSources = Get-WslImageSource -Source Incus
        $imagesSources | Should -Not -BeNullOrEmpty
        $imagesSources.Length | Should -Be 4

        Write-Verbose "Looking for $($alternateMockImage.LocalFilename)" -Verbose
        $localIncus = $imagesSources | Where-Object { $_.LocalFileName -eq $alternateMockImage.LocalFilename }
        $localIncus | Should -Not -BeNullOrEmpty

        $actualImage = New-WslImage -Source $localIncus
        $actualImage | Should -BeOfType [WslImage]
        $actualImage.Source | Should -Not -BeNullOrEmpty
        $actualImage.Source.Id | Should -Be $localIncus.Id
        $actualImage.IsAvailableLocally | Should -BeTrue

        $imagesSources = Get-WslImageSource -Source Builtin
        $imagesSources | Should -Not -BeNullOrEmpty
        $imagesSources.Length | Should -Be 4

        $localBuiltin = $imagesSources | Where-Object { $_.LocalFileName -eq $mockImage.LocalFilename }
        $localBuiltin | Should -Not -BeNullOrEmpty

        $actualImage = New-WslImage -Source $localBuiltin
        $actualImage | Should -BeOfType [WslImage]
        $actualImage.Source | Should -Not -BeNullOrEmpty
        $actualImage.Source.Id | Should -Be $localBuiltin.Id
        $actualImage.IsAvailableLocally | Should -BeTrue

        $imagesSources = Get-WslImageSource -Source All
        $imagesSources.Length | Should -Be 8

        $images = Get-WslImage -Type All
        $images.Length | Should -Be 2
        (($images | Select-Object -ExpandProperty IsAvailableLocally) -contains $true) | Should -BeTrue

        $images = Get-WslImage -State Synced
        $images.Length | Should -Be 2

        $images = Get-WslImage
        $images.Length | Should -Be 2

        $images = @(Get-WslImage -Type Builtin)
        $images.Length | Should -Be 1

        $images = @(Get-WslImage -Os Alpine -Type All)
        $images.Length | Should -Be 1

        $images = @(Get-WslImage -Type Incus)
        $images.Length | Should -Be 1

        $images = @(Get-WslImage -Configured)
        $images.Length | Should -Be 1
    }

    It "Should delete images" {
        $path = $ImageRoot

        $mockImage = New-ImageFromMock -Mock $TestMock
        $alternateMockImage = New-ImageFromMock -Mock $AlternateMock

        Update-WslBuiltinImageCache -Type Builtin | Out-Null
        Update-WslBuiltinImageCache -Type Incus | Out-Null

        $imageSources = Get-WslImageSource -Source All
        $imageSources.Length | Should -Be 8

        $imagesToSync = $imageSources | Where-Object { $_.LocalFileName -in @($TestMock.LocalFilename, $AlternateMock.LocalFilename) }
        $imagesToSync.Length | Should -Be 2

        # Create the images
        $syncRecords = $imagesToSync | New-WslImage

        # Check that files exist
        foreach ($img in $syncRecords) {
            $img.File.Exists | Should -BeTrue
        }

        # Check that images are present
        $images = Get-WslImage
        $images | Should -Not -BeNullOrEmpty
        $images.Length | Should -Be 2
        Write-Test "Images found: $($images)"

        # Delete by name
        $deleted = Remove-WslImage -Name arch
        $deleted | Should -Not -BeNullOrEmpty
        $deleted.IsAvailableLocally | Should -BeFalse
        $deleted.State  | Should -Be NotDownloaded

        # Delete by wildcard
        $deleted = Remove-WslImage -Name alp*  # The name is alpine
        $deleted | Should -Not -BeNullOrEmpty
        $deleted.IsAvailableLocally | Should -BeFalse

        # Check that files are deleted
        foreach ($img in $syncRecords) {
            $img.File.Exists | Should -BeFalse
        }

        # Check that images are gone
        { Remove-WslImage -Name alpine  | Should -Throw }
        Get-WslImage | Should -BeNullOrEmpty
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
            New-BuiltinSourceMock $MockModifiedETag

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
        $Error[0].Exception.Message | Should -Match "Failed to retrieve image sources*"
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

    It "Should convert PSObject with nested table to hashtable" {
        InModuleScope Wsl-Manager {
            $source = [PSCustomObject]@{
                Name = "Test"
                Nested = [PSCustomObject]@{
                    Key1 = "Value1"
                    Key2 = "Value2"
                }
                NestedTable = @(
                    [PSCustomObject]@{
                        Key1 = "Value1"
                        Key2 = "Value2"
                    },
                    [PSCustomObject]@{
                        Key1 = "Value3"
                        Key2 = "Value4"
                    }
                )
            }

            $expected = @{
                Name = "Test"
                Nested = @{
                    Key1 = "Value1"
                    Key2 = "Value2"
                }
                NestedTable = @(
                    @{
                        Key1 = "Value1"
                        Key2 = "Value2"
                    },
                    @{
                        Key1 = "Value3"
                        Key2 = "Value4"
                    }
                )
            }

            $result = Convert-PSObjectToHashtable -InputObject $source
            $result -is [hashtable] | Should -BeTrue
            $result.Nested -is [hashtable] | Should -BeTrue
            $result.NestedTable -is [System.Collections.IEnumerable] | Should -BeTrue
            $result.NestedTable[0] -is [hashtable] | Should -BeTrue
            $result.NestedTable[1] -is [hashtable] | Should -BeTrue
            $result.NestedTable[0]['Key1'] | Should -Be "Value1"
            # TODO: Make a recursive check for all keys and values
        }
    }

    It "Should start download" {
        $Url = [System.Uri]::new("https://example.com/image.tar.gz")
        $path = [FileInfo]::new((Join-Path -Path $ImageRoot -ChildPath "image.tar.gz"))

        InModuleScope Wsl-Manager {
            Mock Start-Download { Write-Mock "Start Download" }
            Sync-File -Url $Url -File $path
            Should -Invoke -CommandName Start-Download -Times 1 -ParameterFilter {
                $PesterBoundParameters.Url -eq $Url -and
                $PesterBoundParameters.File.FullName -eq $path
            }
        }
    }

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

        New-ImageFromMock -Mock $AlternateMock | Out-Null

        $image = New-WslImage -Source $imageSource

        $image | Should -Not -BeNullOrEmpty
        $image.IsAvailableLocally | Should -BeTrue
        $image.State | Should -Be "Synced"
        $image.Type | Should -Be "Incus"
    }
}
