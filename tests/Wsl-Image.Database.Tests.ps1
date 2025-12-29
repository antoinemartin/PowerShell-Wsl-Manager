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

Describe 'WslImage.Database' {
    BeforeAll {
        # Create a temporary WSL root for testing
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "RootFS"
        $EmptyHash = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
        [WslImageDatabase]::DatabaseFileName = [FileInfo]::new((Join-Path $ImageRoot "images.db"))
        $SavedCurrentVersion = [WslImageDatabase]::CurrentVersion

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
        [WslImageDatabase]::CurrentVersion = $SavedCurrentVersion
    }

    It "Should create the database file" {
        try {
            $db = [WslImageDatabase]::new()
            [WslImageDatabase]::DatabaseFileName.Exists | Should -Be $false
            $db.Open()
            [WslImageDatabase]::DatabaseFileName.Refresh()
            ([WslImageDatabase]::DatabaseFileName.Exists) | Should -Be $true
            $db.IsOpen() | Should -Be $true
            $db.IsUpdatePending() | Should -Be $true
        } finally {
            $db.Close()
        }
    }

    It "Should update the database if needed" {
        try {
            [WslImageDatabase]::CurrentVersion = 1
            $db = [WslImageDatabase]::new()
            $db.Open()
            $db.UpdateIfNeeded([WslImageDatabase]::CurrentVersion)
            $db.IsUpdatePending() | Should -Be $false
            $ds = $db.db.ExecuteQuery("PRAGMA user_version;")
            $ds.Tables.Count | Should -Be 1
            $rs = $ds.Tables[0]
            $rs[0].user_version | Should -Be ([WslImageDatabase]::CurrentVersion)
            $ds = $db.db.ExecuteQuery("select * from sqlite_master where type='table';")
            $ds.Tables.Count | Should -Be 1
            $rs = $ds.Tables[0]
            $rs.Rows.Count | Should -Be 3
            $rs | Where-Object { $_.name -eq "ImageSource" } | Should -Not -Be $null
            $rs | Where-Object { $_.name -eq "LocalImage" } | Should -Not -Be $null
            $rs | Where-Object { $_.name -eq "ImageSourceCache" } | Should -Not -Be $null
            # Test that the version is read correctly after re-opening the db
            $db.Close()
            $db.Open()
            $db.version | Should -Be ([WslImageDatabase]::CurrentVersion)
            $db.IsUpdatePending() | Should -Be $false
        } finally {
            $db.Close()
        }
    }

    It "Should throw when operating on a closed db" {
        $db = [WslImageDatabase]::new()
        { $db.UpdateIfNeeded(1) } | Should -Throw
        { $db.CreateDatabaseStructure() } | Should -Throw
        $db.Open()
        { $db.Open() } | Should -Throw
        { $db.Close() } | Should -Not -Throw
    }

    It "Should auto-close the database" {
        [WslImageDatabase]::SessionCloseTimeout = 500
        [WslImageDatabase]::CurrentVersion = 1
        InModuleScope -ModuleName Wsl-Manager {
            $db = Get-WslImageDatabase
            $db.IsOpen() | Should -Be $true
            Write-Test "Waiting for the event to trigger"
            Wait-Event [WslImageDatabase]::SessionCloseTimer.Elapsed -Timeout 1
            $db.IsOpen() | Should -Be $false
        }
    }

    Context "Builtins" {
        BeforeEach {
            # Copy builtin files from fixtures to the image root
            Get-ChildItem -Path (Join-Path $PSScriptRoot "fixtures") -Filter '*.rootfs.json' | Copy-Item -Destination $ImageRoot

            # Open the database and migrate the files
            [WslImageDatabase]::CurrentVersion = 3
            $db = [WslImageDatabase]::new()
            $db.Open()
            $db.UpdateIfNeeded(3)
            $db.IsUpdatePending() | Should -Be $false
        }

        AfterEach {
            $db.Close()
        }

        It "Should migrate builtins" {

            $dt = $db.db.ExecuteSingleQuery("select count(*) as cnt from ImageSource;")
            $dt | Should -Not -Be $null
            $dt.Rows.Count | Should -Be 1
            $dt.Rows[0].cnt | Should -Be 74
            $dt = $db.db.ExecuteSingleQuery("select count(*) as cnt from ImageSourceCache;")
            $dt | Should -Not -Be $null
            $dt.Rows.Count | Should -Be 1
            $dt.Rows[0].cnt | Should -Be 2
            Write-Host $dt.Rows[0].Type
        }

        It "Should return Image Source Cache" {
            $dbCache = $db.GetImageSourceCache(0)
            $dbCache | Should -Not -Be $null
            $dbCache.Type | Should -Be "Builtin"
            $dbCache.LastUpdate | Should -BeGreaterThan 0
            $dbCache.Etag | Should -Not -Be $null
            $dbCache = $db.GetImageSourceCache(1)
            $dbCache | Should -Not -Be $null
            $dbCache.Type | Should -Be "Incus"
            $dbCache.LastUpdate | Should -BeGreaterThan 0
            $dbCache.Etag | Should -Not -Be $null
        }

        It "Should return Builtin images" {
            $images = $db.GetImageBuiltins(0)
            $images | Should -Not -Be $null
            $images.Count | Should -Be 10
            ($images | Group-Object -Property Distribution).Count | Should -Be 5
            $images = $db.GetImageBuiltins(1)
            $images | Should -Not -Be $null
            $images.Count | Should -Be 64
            $imageObject = $images[0]
            $image = [WslImageSource]::new($imageObject)
            $image | Should -Not -Be $null
            $imageObject.Id | Should -Not -Be $null
            $imageObject.Tags | Should -Not -Be $null
            $imageObject.Tags.Count | Should -Be 1
            $imageObject.Tags = @($imageObject.Tags,"new-tag")
            $imageObject.Tags.Count | Should -Be 2
            $db.SaveImageBuiltins(0, @($imageObject), "MockedTag")
            # Now get the db record. Test upsert
            $db.db.ExecuteSingleQuery("select * from ImageSource where Id = '$($imageObject.Id)';") | ForEach-Object {
                $_.Tags -split ',' | Should -Contain "new-tag"
            }
        }

        It "Should fail inserting bad Builtin images" {
            $badImage = [PSCustomObject]@{
                Id = $null
                Distribution = "ubuntu"
                Version = "20.04"
                Architecture = "x86_64"
                Type = "Uri"
                Tags = @("latest")
                SourceType = "Builtin"
                SourceId = 0
                BlobUrl = "http://example.com/ubuntu.tar.gz"
                ImageDigest = "abcdef1234567890"
                HashSource = {
                    Algorithm = "SHA256"
                    Type = "sums"
                    Url = "http://example.com/SHA256SUMS"
                }
            }
            { $db.SaveImageBuiltins(0, @($badImage), "BadImage") } | Should -Throw "Failed to insert or update image *"
        }

        It "Should update image source cache" {
            $dbCache = $db.GetImageSourceCache(0)
            $oldEtag = $dbCache.Etag
            $oldLastUpdate = $dbCache.LastUpdate
            Start-Sleep -Seconds 1
            $dbCache.Etag = "new-etag"
            $dbCache.LastUpdate = [int][double]::Parse((Get-Date -UFormat %s))
            $db.UpdateImageSourceCache(0, $dbCache)
            $dbCache = $db.GetImageSourceCache(0)
            $dbCache.Etag | Should -Be "new-etag"
            $dbCache.LastUpdate | Should -BeGreaterThan $oldLastUpdate
        }

        It "Should add GroupTag column" {
            # Verify that the column exists
            $dt = $db.db.ExecuteSingleQuery("PRAGMA table_info('ImageSource');")
            $dt | Should -Not -Be $null
            $dt.Rows.Count | Should -BeGreaterThan 0
            ($dt.Rows | Where-Object { $_.name -eq "GroupTag" }) | Should -Not -Be $null

            # Verify that the group tags have been set for built-in images
            $dt = $db.db.ExecuteSingleQuery("select distinct GroupTag from ImageSource;")
            $dt | Should -Not -Be $null
            $dt.Rows.Count | Should -Be 2
        }

        It "Should save local image without HashSource property" {
            $db.UpdateIfNeeded(7)
            $localImage = [PSCustomObject]@{
                Id = [Guid]::NewGuid().ToString()
                Name = "debian"
                Distribution = "Debian"
                Release = "11"
                Type = "Uri"
                Tags = @("latest")
                ImageSourceId = $null
                Url = "http://example.com/debian.tar.gz"
                Digest = $EmptyHash
                DigestAlgorithm = "SHA256"
                DigestSource = "sums"
                DigestUrl = "http://example.com/SHA256SUMS"
                State = 'NotDownloaded'
                Configured = $false
                Username = "root"
                Uid = 0
                LocalFileName = "$EmptyHash.rootfs.tar.gz"
                Size = 12345678
            }
            $db.SaveLocalImage($localImage)
            # Now get the db record
            $db.db.ExecuteSingleQuery("select * from LocalImage where Id = '$($localImage.Id)';") | ForEach-Object {
                $_.Id | Should -Be $localImage.Id
                $_.Name | Should -Be $localImage.Name
                $_.Distribution | Should -Be $localImage.Distribution
                $_.Release | Should -Be $localImage.Release
                $_.Type | Should -Be $localImage.Type
                ($_.Tags -split ',') | Should -Contain "latest"
                $_.Type | Should -Be "Uri"
                $_.ImageSourceId | Should -BeNullOrEmpty
                $_.Url | Should -Be $localImage.Url
                $_.Digest | Should -Be $localImage.Digest
                $_.DigestAlgorithm | Should -Be $localImage.DigestAlgorithm
                $_.DigestSource | Should -Be $localImage.DigestSource
                $_.DigestUrl | Should -Be $localImage.DigestUrl
                $_.State | Should -Be $localImage.State
                $_.Configured | Should -Be 'FALSE'
                $_.Username | Should -Be $localImage.Username
                $_.Uid | Should -Be $localImage.Uid
                $_.LocalFileName | Should -Be $localImage.LocalFileName
                $_.Size | Should -Be $localImage.Size
            }
        }

        It "Should fail to save local image without Name" {
            $db.UpdateIfNeeded(7)
            $localImage = [PSCustomObject]@{
                Id = [Guid]::NewGuid().ToString()
                Name = $null
                Distribution = "Debian"
                Release = "11"
                Type = "Uri"
                Tags = @("latest")
                ImageSourceId = $null
                Url = "http://example.com/debian.tar.gz"
                Digest = $EmptyHash
                DigestAlgorithm = "SHA256"
                DigestSource = "sums"
                DigestUrl = "http://example.com/SHA256SUMS"
                State = 'NotDownloaded'
                Configured = $false
                Username = "root"
                Uid = 0
                LocalFileName = "$EmptyHash.rootfs.tar.gz"
                Size = 12345678
            }
            { $db.SaveLocalImage($localImage) } | Should -Throw "Failed to insert or update local image *"
        }

        It "Should fail to save image source without name" {
            $db.UpdateIfNeeded(7)
            $imageSource = [PSCustomObject]@{
                Id = [Guid]::NewGuid().ToString()
                Name = $null
                Distribution = "Debian"
                Version = "20.04"
                Type = "Uri"
                Tags = @("latest")
                ImageSourceId = $null
                Url = "http://example.com/debian.tar.gz"
                Digest = $EmptyHash
                DigestAlgorithm = "SHA256"
                DigestSource = "sums"
                DigestUrl = "http://example.com/SHA256SUMS"
                Configured = $false
                Username = "root"
                Uid = 0
                LocalFileName = "$EmptyHash.rootfs.tar.gz"
                Size = 12345678
                GroupTag = "TestGroup"
            }
            { $db.SaveImageSource($imageSource) } | Should -Throw "Failed to insert or update image source *"
        }

        It "Should fail creating an image from an unknown image source" {
            $db.UpdateIfNeeded(7)
            { $db.CreateLocalImageFromImageSource([guid]::NewGuid()) } | Should -Throw "Image source with ID * not found.*"
        }

    }
}
