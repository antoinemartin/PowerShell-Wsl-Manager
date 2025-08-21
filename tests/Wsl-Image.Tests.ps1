using namespace System.IO;

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification='This is a test file, global variables are used to share fixtures across tests.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
    Justification="Mock functions don't need ShouldProcess")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
Param()


BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module "$PSScriptRoot/TestAssertions.psm1" -DisableNameChecking
}


BeforeAll {
    Import-Module Wsl-Manager
    Import-Module $PSScriptRoot\TestUtils.psm1 -Force

    # Write-Test "Write-Mock enabled"
    # Set-MockPreference $true

    # Define a global constant for the empty hash
    $TestFilename = 'docker.arch.rootfs.tar.gz'
    $AlternateFilename = 'incus.alpine_3.19.rootfs.tar.gz'
}

Describe "WslImage" {
    BeforeAll {
        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "RootFS"
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()

        InModuleScope -ModuleName Wsl-Manager {
            $global:builtinsSourceUrl = $WslImageSources[[WslImageSource]::Builtins]
            $global:incusSourceUrl = $WslImageSources[[WslImageSource]::Incus]
        }
        New-BuiltinSourceMock
        New-IncusSourceMock
    }
    BeforeEach {
        Mock Sync-File { Write-Mock "download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File } -ModuleName Wsl-Manager
        New-GetDockerImageMock
        InModuleScope -ModuleName Wsl-Manager {
            $WslImageCacheFileCache.Clear()
        }
    }
    AfterEach {
        Get-ChildItem -Path ([WslImage]::BasePath).FullName | Remove-Item -Force
    }

    It "should split Incus names" {
        $Image = [WslImage]::new("incus://almalinux#9")
        $Image.Os | Should -Be "almalinux"
        $Image.Release | Should -Be "9"
        $Image.Type | Should -Be "Incus"

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ModuleName Wsl-Manager
    }

    It "Should fail on bad Incus names" {
        { [WslImage]::new("incus://badlinux#9") } | Should -Throw "Unknown Incus distribution with OS badlinux and Release 9. Check https://images.linuxcontainers.org/images."
    }

    It "Should Recognize Builtin distributions" {


        $Image = [WslImage]::new("alpine-base")
        $Image.Os | Should -Be "Alpine"
        $Image.Release | Should -Be $MockBuiltins[0].Release
        $Image.Configured | Should -BeFalse
        $Image.Type | Should -Be "Builtin"
        $Image.Url | Should -Be $MockBuiltins[0].Url
        $Image.Username | Should -Be "root"
        $Image.Uid | Should -Be 0

        $Image = [WslImage]::new("alpine")
        $Image.Configured | Should -BeTrue
        $Image.Url | Should -Be $MockBuiltins[1].Url
        $Image.Username | Should -Be "alpine"
        $Image.Uid | Should -Be 1000
    }

    It "Should split properly external URL" {
        $url = "https://kali.download/nethunter-images/current/Image/kalifs-amd64-minimal.tar.xz"
        $Image = [WslImage]::new($url)
        $Image.Os | Should -Be "Kalifs"
        $Image.Release | Should -Be "unknown"
        $Image.Configured | Should -BeFalse
        $Image.Type | Should -Be "Uri"
        $Image.Url | Should -Be $url
    }

    It "Should download distribution" {
        [WslImage]::HashSources.Clear()

        try {
            $Image = [WslImage]::new("alpine")
            $Image.Os | Should -Be "Alpine"
            $Image.Release | Should -Be $MockBuiltins[1].Release
            $Image.Configured | Should -BeTrue
            $Image.Type | Should -Be "Builtin"
            $Image.IsAvailableLocally | Should -BeFalse
            $Image | Sync-WslImage
            $Image.IsAvailableLocally | Should -BeTrue
            $Image.LocalFileName | Should -Be "docker.alpine.rootfs.tar.gz"
            $Image.File.Exists | Should -BeTrue
            Should -Invoke -CommandName Get-DockerImage -Times 1 -ModuleName Wsl-Manager

            # Test presence of metadata file
            $metaFile = Join-Path -Path ([WslImage]::BasePath) -ChildPath "docker.alpine.rootfs.tar.gz.json"
            Test-Path $metaFile | Should -BeTrue
            $meta = Get-Content $metaFile | ConvertFrom-Json
            # Check that $meta has this structure
            # {
            # "Uid": 1000,
            # "Release": "3.22",
            # "Url": "docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine#latest",
            # "Os": "Alpine",
            # "Type": "Builtin",
            # "State": "Synced",
            # "FileHash": "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
            # "HashSource": {
            #     "Mandatory": true,
            #     "Type": "docker",
            #     "Algorithm": "SHA256"
            # },
            # "Configured": true,
            # "Name": "alpine",
            # "Username": "alpine"
            # }
            #
            $meta | Should -HaveProperty "Uid"
            $meta | Should -HaveProperty "Release"
            $meta | Should -HaveProperty "Url"
            $meta | Should -HaveProperty "Os"
            $meta | Should -HaveProperty "Type"
            $meta | Should -HaveProperty "State"
            $meta | Should -HaveProperty "FileHash"
            $meta | Should -HaveProperty "HashSource"
            $meta | Should -HaveProperty "Configured"
            $meta | Should -HaveProperty "Name"
            $meta | Should -HaveProperty "Username"
            # Check that HashSource has the expected properties
            $meta.HashSource | Should -HaveProperty "Mandatory"
            $meta.HashSource | Should -HaveProperty "Type"
            $meta.HashSource | Should -HaveProperty "Algorithm"
            # Check values
            $meta.Uid | Should -Be 1000
            $meta.Release | Should -Be "3.22.1"
            $meta.Url | Should -Be "docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine#latest"
            $meta.Os | Should -Be "Alpine"
            $meta.Type | Should -Be "Builtin"
            $meta.State | Should -Be "Synced"
            $meta.FileHash | Should -Be $EmptySha256
            $meta.HashSource.Mandatory | Should -Be $true
            $meta.HashSource.Type | Should -Be "docker"
            $meta.HashSource.Algorithm | Should -Be "SHA256"
        }
        finally {
            $path = [WslImage]::BasePath.FullName
            Get-ChildItem -Path $path | Remove-Item
        }
    }

    It "Should download image by URL" {

        Mock Get-DockerImage { throw  [System.Net.WebException]::new("test", 7) }  -ModuleName Wsl-Manager
        [WslImage]::HashSources.Clear()

        try {
            $Image = [WslImage]::new("https://github.com/kaweezle/iknite/releases/download/v0.2.1/kaweezle.rootfs.tar.gz")
            $Image.Os | Should -Be "kaweezle"
            $Image.Release | Should -Be "unknown"
            $Image.Configured | Should -BeFalse
            $Image.Type | Should -Be "Uri"
            $Image.IsAvailableLocally | Should -BeFalse
            $Image | Sync-WslImage
            $Image.IsAvailableLocally | Should -BeTrue
            $Image.LocalFileName | Should -Be "kaweezle.rootfs.tar.gz"
            $Image.File.Exists | Should -BeTrue
            Should -Invoke -CommandName Sync-File -Times 1 -ModuleName Wsl-Manager

            # Test presence of metadata file
            $metaFile = Join-Path -Path $ImageRoot -ChildPath "kaweezle.rootfs.tar.gz.json"
            Test-Path $metaFile | Should -BeTrue
            $meta = Get-Content $metaFile | ConvertFrom-Json
            $meta | Should -HaveProperty "Type"
            $meta.Type | Should -Be "Uri"

            # Will fail because of exception thrown by Mock Get-DockerImage
            $Image = [WslImage]::new("alpine")
            { $Image | Sync-WslImage } | Should -Throw "Error while loading distro *"

        }
        finally {
            $path = [WslImage]::BasePath.FullName
            Get-ChildItem -Path $path | Remove-Item
        }
    }

    # FIXME: This test does not work for OCI image based distributions
    It "Shouldn't download already present file" {
        $path = [WslImage]::BasePath.FullName
        New-Item -Path $path -Name $TestFilename -ItemType File
        Mock Get-DockerImageLayerManifest { return @{
            digest = "sha256:$($EmptySha256)"
        } }  -ModuleName Wsl-Manager

        [WslImage]::HashSources.Clear()

        try {
            $Image = [WslImage]::new("arch")
            $Image.IsAvailableLocally | Should -BeTrue
            $Image.FileHash | Should -Be $EmptySha256
            $Image | Sync-WslImage
            Should -Invoke -CommandName Get-DockerImage -Times 0 -ModuleName Wsl-Manager
        }
        finally {
            Get-ChildItem -Path $path | Remove-Item
        }
    }

    It "Should get values from builtin distributions" {

        $path = [WslImage]::BasePath.FullName
        $file = New-Item -Path $path -Name $TestFilename -ItemType File
        $fileSystem = [WslImage]::new($file)
        $fileSystem | Should -BeOfType [WslImage]
        $fileSystem.Name | Should -Be "arch"
        $fileSystem.Release | Should -Be $MockBuiltins[3].Release
        $fileSystem.Configured | Should -BeTrue
    }

    It "Should return local images" {
        $path = $ImageRoot
        New-Item -Path $path -Name $TestFilename -ItemType File
        New-Item -Path $path -Name $AlternateFilename  -ItemType File

        try {
            $distributions = Get-WslImage -Source Incus
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Length | Should -Be 4

            $distributions = Get-WslImage -Source Builtins
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Length | Should -Be 4

            $distributions = Get-WslImage -Source All
            $distributions.Length | Should -Be 8
            (($distributions | Select-Object -ExpandProperty IsAvailableLocally) -contains $true) | Should -BeTrue

            $distributions = Get-WslImage -State Synced
            $distributions.Length | Should -Be 2

            $distributions = Get-WslImage
            $distributions.Length | Should -Be 2

            $distributions = @(Get-WslImage -Type Builtin)
            $distributions.Length | Should -Be 1

            $distributions = Get-WslImage -Type Builtin -Source All
            $distributions.Length | Should -Be 4

            $distributions = Get-WslImage -Os Alpine -Source All
            $distributions.Length | Should -Be 4

            Get-WslImage
            $distributions = @(Get-WslImage -Type Incus)
            $distributions.Length | Should -Be 1

            $distributions = @(Get-WslImage -Configured)
            $distributions.Length | Should -Be 1
        }
        finally {
            Get-ChildItem -Path $path | Remove-Item
        }

    }

    It "Should delete images" {
        $path = [WslImage]::BasePath.FullName
        New-Item -Path $path -Name $TestFilename -ItemType File
        New-Item -Path $path -Name $AlternateFilename  -ItemType File

        try {
            $distributions = Get-WslImage
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Length | Should -Be 2
            Write-Test "Distributions found: $($distributions)"

            $deleted = Remove-WslImage arch
            $deleted | Should -Not -BeNullOrEmpty
            $deleted.IsAvailableLocally | Should -BeFalse
            $deleted.State  | Should -Be NotDownloaded

            $deleted = Remove-WslImage alpine_*  # The name is alpine_3.19
            $deleted | Should -Not -BeNullOrEmpty
            $deleted.IsAvailableLocally | Should -BeFalse

            { Remove-WslImage alpine  | Should -Throw }

        }
        finally {
            Get-ChildItem -Path $path | Remove-Item
        }

    }

    It "Should check image hashes" {
        $HASH_DATA = @"
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
$EmptySha256  docker.alpine.rootfs.tar.gz
"@
        Mock Sync-String { Write-Mock "return hash data"; return $HASH_DATA }  -ModuleName Wsl-Manager -Verifiable

        $path = $ImageRoot
        $alpineFile = New-Item -Path $path -Name 'docker.alpine.rootfs.tar.gz' -ItemType File
        $archFile = New-Item -Path $path -Name 'archlinux.rootfs.tar.gz'  -ItemType File
        try {
            $hashes = New-WslImageHash 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/SHA256SUMS'
            $hashes.Algorithm | Should -Be 'SHA256'
            $hashes.Type | Should -Be 'sums'

            $hashes.Retrieve()
            $hashes.Hashes.Count | Should -Be 2
            Should -Invoke -CommandName Sync-String -Times 1 -ModuleName Wsl-Manager

            Write-Test "Ok with right hash"
            $digest = $hashes.DownloadAndCheckFile("https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/docker.alpine.rootfs.tar.gz", $alpineFile)
            $digest | Should -Be $EmptySha256

            Write-Test "Throw if hash not present"
            { $hashes.DownloadAndCheckFile([System.Uri]"http://example.com/unknown.rootfs.tar.gz", $alpineFile) } | Should -Throw

            Write-Test "Throw if hash is wrong"
            { $hashes.DownloadAndCheckFile([System.Uri]"http://example.com/archlinux.rootfs.tar.gz", $archFile) } | Should -Throw

            Write-Test "Download docker and check inline"
            $digest = $hashes.DownloadAndCheckFile($MockBuiltins[1].Url, $alpineFile)
            $digest | Should -Be $EmptySha256
        }
        finally {
            Get-ChildItem -Path $path | Remove-Item
        }
    }

    It "Should check single hash" {
        $HASH_DATA = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

        Mock Sync-String { return $HASH_DATA }  -ModuleName Wsl-Manager

        $path = $ImageRoot
        $url = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
        New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
        try {
            $toCheck = New-WslImage alpine
            $hashes = New-WslImageHash "$url.sha256" -Type 'single'
            $hashes.Algorithm | Should -Be 'SHA256'
            $hashes.Type | Should -Be 'single'

            $hashes.Retrieve()
            $hashes.Hashes.Count | Should -Be 1

            $hashes.DownloadAndCheckFile([System.Uri]$url, $toCheck.File) | Should -Not -BeNullOrEmpty

        }
        finally {
            Get-ChildItem -Path $path | Remove-Item
        }

    }
    It "Should download and cache builtin images" {
        $root =  $ImageRoot

        Write-Test "First call"
        $distributions = Get-WslBuiltinImage
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be 4

        $builtinsFile = Join-Path -Path $root -ChildPath "builtins.rootfs.json"
        $builtinsFile | Should -Exist
        $cache = Get-Content -Path $builtinsFile | ConvertFrom-Json
        $firstLastUpdate = $cache.lastUpdate
        $firstLastUpdate | Should -BeGreaterThan 0
        $cache.etag | Should -Not -BeNullOrEmpty
        $cache.etag[0] | Should -Be "MockedTag"
        $cache.Url | Should -Be "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json"

        # Now calling again should hit the cache
        Write-Test "Cached call"
        $distributions = Get-WslBuiltinImage
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be $MockBuiltins.Count

        Should -Invoke -CommandName Invoke-WebRequest -Times 0 -ParameterFilter {
            $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
        } -ModuleName Wsl-Manager

        # Now clear the cache to read from file
        Write-Test "File Cache Call"
        InModuleScope -ModuleName Wsl-Manager {
            $WslImageCacheFileCache.Clear()
        }
        $distributions = Get-WslBuiltinImage
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be $MockBuiltins.Count

        Should -Invoke -CommandName Invoke-WebRequest -Times 0 -ParameterFilter {
            $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
        } -ModuleName Wsl-Manager

        # Now do it with synchronization after sleeping for one second
        Write-Test "Force sync call (1 second later)"
        Start-Sleep -Seconds 1
        $distributions = Get-WslBuiltinImage -Sync
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be $MockBuiltins.Count

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ParameterFilter {
            $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
        } -ModuleName Wsl-Manager

        # test that builtins lastUpdate is newer
        $builtinsFile | Should -Exist
        $cache = InModuleScope -ModuleName Wsl-Manager {
            $WslImageCacheFileCache[[WslImageSource]::Builtins]
        }

        $cache.lastUpdate | Should -BeGreaterThan $firstLastUpdate

        # Force lastUpdate to yesterday to trigger a refresh
        $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
        $cache.lastUpdate = $currentTime - 86410
        $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $builtinsFile -Force

        Write-Test "Call one day later without changes"
        $distributions = Get-WslBuiltinImage
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be $MockBuiltins.Count

        Should -Invoke -CommandName Invoke-WebRequest -Times 2 -ParameterFilter {
            $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
        } -ModuleName Wsl-Manager
        $builtinsFile | Should -Exist
        $cache = Get-Content -Path $builtinsFile | ConvertFrom-Json
        $cache.lastUpdate | Should -BeGreaterThan $firstLastUpdate -Because "Cache was refreshed so the lastUpdate should be greater."

        $cache = InModuleScope -ModuleName Wsl-Manager {
            $WslImageCacheFileCache[[WslImageSource]::Builtins]
        }
        $cache.lastUpdate = $currentTime - 86410
        $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $builtinsFile -Force
        New-BuiltinSourceMock $MockModifiedETag

        Write-Test "Call one day later (lastUpdate $($cache.lastUpdate), currentTime $($currentTime)) with changes (new etag)"
        $distributions = Get-WslBuiltinImage
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be $MockBuiltins.Count

        Should -Invoke -CommandName Invoke-WebRequest -Times 2 -ParameterFilter {
            $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
        } -ModuleName Wsl-Manager
        $builtinsFile | Should -Exist
        $cache = Get-Content -Path $builtinsFile | ConvertFrom-Json
        $cache.lastUpdate | Should -BeGreaterThan $firstLastUpdate -Because "Cache was refreshed so the lastUpdate should be greater."
        $cache.etag | Should -Not -BeNullOrEmpty
        $cache.etag[0] | Should -Be "NewMockedTag"
    }

    It "should fail nicely on builtin images" {
        Write-Test "Web exception"
        Mock Invoke-WebRequest { Write-Mock "Here 2"; throw [System.Net.WebException]::new("test", 7) } -ModuleName Wsl-Manager -Verifiable -ParameterFilter {
            return $true
        }

        { Get-WslBuiltinImage } | Should -Throw "The response content from *"

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

        $images = Get-WslBuiltinImage
        $images | Should -BeNullOrEmpty
        $Error[0] | Should -Not -BeNullOrEmpty
        $Error[0].Exception.Message | Should -Match "Failed to retrieve builtin root filesystems: Conversion from JSON failed with *"
    }

    It "Should download and cache incus images" {
        $root =  $ImageRoot
        Write-Test "First call"
        $distributions = Get-WslBuiltinImage -Source Incus
        $distributions | Should -Not -BeNullOrEmpty
        $distributions.Count | Should -Be $MockIncus.Count

        $builtinsFile = Join-Path -Path $root -ChildPath "incus.rootfs.json"
        $builtinsFile | Should -Exist
        $cache = Get-Content -Path $builtinsFile | ConvertFrom-Json
        $firstLastUpdate = $cache.lastUpdate
        $firstLastUpdate | Should -BeGreaterThan 0
        $cache.etag | Should -Not -BeNullOrEmpty
        $cache.etag[0] | Should -Be "MockedTag"
        $cache.Url | Should -Be "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json"
    }
}
