using namespace System.IO;
using module .\Wsl-RootFS.psm1

Update-TypeData -PrependPath .\Wsl-Manager.Types.ps1xml
Update-FormatData -PrependPath .\Wsl-Manager.Format.ps1xml

# Define a global constant for the empty hash
$global:EmptyHash = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module "$PSScriptRoot/TestAssertions.psm1" -DisableNameChecking
}

# Define a global constant for the empty hash
$global:EmptyHash = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

Describe "WslRootFileSystem" {
    BeforeAll {
        [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($(Join-Path $TestDrive "WslRootFS"))
        [WslRootFileSystem]::BasePath.Create()
    }
    InModuleScope "Wsl-RootFS" {
        BeforeEach {
            Mock Sync-File { Progress "Mock download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File }
            Mock Get-DockerImageLayer {
                Progress "Mock getting Docker image layer for $($DestinationFile)..."
                New-Item -Path $DestinationFile -ItemType File | Out-Null
                return $global:EmptyHash
              }
        }

        It "should split Incus names" {
            $rootFs = [WslRootFileSystem]::new("incus://almalinux#9")
            $rootFs.Os | Should -Be "almalinux"
            $rootFs.Release | Should -Be "9"
            $rootFs.Type -eq [WslRootFileSystemType]::Incus | Should -BeTrue
        }

        It "Should fail on bad Incus names" {
            { [WslRootFileSystem]::new("incus://badlinux#9") } | Should -Throw "Unknown Incus distribution with OS badlinux and Release 9. Check https://images.linuxcontainers.org/images."
        }

        It "Should Recognize Builtin distributions" {
            $rootFs = [WslRootFileSystem]::new("alpine-base")
            $rootFs.Os | Should -Be "Alpine"
            $rootFs.Release | Should -Be "3.22"
            $rootFs.Configured | Should -BeFalse
            $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
            $rootFs.Url | Should -Be $($script:Distributions['Alpine-base']['Url'])
            $rootFs.Username | Should -Be "root"
            $rootFs.Uid | Should -Be 0

            $rootFs = [WslRootFileSystem]::new("alpine")
            $rootFs.Configured | Should -BeTrue
            $rootFs.Url | Should -Be $($script:Distributions['Alpine']['Url'])
            $rootFs.Username | Should -Be "alpine"
            $rootFs.Uid | Should -Be 1000
        }

        It "Should split properly external URL" {
            $url = "https://kali.download/nethunter-images/current/rootfs/kalifs-amd64-minimal.tar.xz"
            $rootFs = [WslRootFileSystem]::new($url)
            $rootFs.Os | Should -Be "Kalifs"
            $rootFs.Release | Should -Be "unknown"
            $rootFs.Configured | Should -BeFalse
            $rootFs.Type -eq [WslRootFileSystemType]::Uri | Should -BeTrue
            $rootFs.Url | Should -Be $url
        }

        It "Should download distribution" {
            [WslRootFileSystem]::HashSources.Clear()

            try {
                $rootFs = [WslRootFileSystem]::new("alpine")
                $rootFs.Os | Should -Be "Alpine"
                $rootFs.Release | Should -Be "3.22"
                $rootFs.Configured | Should -BeTrue
                $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
                $rootFs.IsAvailableLocally | Should -BeFalse
                $rootFs | Sync-WslRootFileSystem
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.LocalFileName | Should -Be "docker.alpine.rootfs.tar.gz"
                $rootFs.File.Exists | Should -BeTrue
                Should -Invoke -CommandName Get-DockerImageLayer -Times 1

                # Test presence of metadata file
                $metaFile = Join-Path -Path ([WslRootFileSystem]::BasePath) -ChildPath "docker.alpine.rootfs.tar.gz.json"
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
                $meta.Release | Should -Be "3.22"
                $meta.Url | Should -Be "docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine#latest"
                $meta.Os | Should -Be "Alpine"
                $meta.Type | Should -Be "Builtin"
                $meta.State | Should -Be "Synced"
                $meta.FileHash | Should -Be $global:EmptyHash
                $meta.HashSource.Mandatory | Should -Be $true
                $meta.HashSource.Type | Should -Be "docker"
                $meta.HashSource.Algorithm | Should -Be "SHA256"
            }
            finally {
                $path = [WslRootFileSystem]::BasePath.FullName
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Should download root filesystem by URL" {

            Mock Get-DockerImageLayer { throw  [System.Net.WebException]::new("test", 7) }
            [WslRootFileSystem]::HashSources.Clear()

            try {
                $rootFs = [WslRootFileSystem]::new("https://github.com/kaweezle/iknite/releases/download/v0.2.1/kaweezle.rootfs.tar.gz")
                $rootFs.Os | Should -Be "kaweezle"
                $rootFs.Release | Should -Be "unknown"
                $rootFs.Configured | Should -BeFalse
                $rootFs.Type -eq [WslRootFileSystemType]::Uri | Should -BeTrue
                $rootFs.IsAvailableLocally | Should -BeFalse
                $rootFs | Sync-WslRootFileSystem
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.LocalFileName | Should -Be "kaweezle.rootfs.tar.gz"
                $rootFs.File.Exists | Should -BeTrue
                Should -Invoke -CommandName Sync-File -Times 1

                # Test presence of metadata file
                $metaFile = Join-Path -Path ([WslRootFileSystem]::BasePath) -ChildPath "kaweezle.rootfs.tar.gz.json"
                Test-Path $metaFile | Should -BeTrue
                $meta = Get-Content $metaFile | ConvertFrom-Json
                $meta | Should -HaveProperty "Type"
                $meta.Type | Should -Be "Uri"

                # Will fail because of exception thrown by Mock Get-DockerImageLayer
                $rootFs = [WslRootFileSystem]::new("alpine")
                { $rootFs | Sync-WslRootFileSystem } | Should -Throw "Error while loading distro *"

            }
            finally {
                $path = [WslRootFileSystem]::BasePath.FullName
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        # FIXME: This test does not work for OCI image based distributions
        It "Shouldn't download already present file" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'docker.arch.rootfs.tar.gz' -ItemType File
            Mock Get-DockerImageLayerManifest { return @{
                digest = "sha256:$($global:EmptyHash)"
            } }

            [WslRootFileSystem]::HashSources.Clear()

            try {
                $rootFs = [WslRootFileSystem]::new("arch")
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.FileHash | Should -Be $global:EmptyHash
                $rootFs | Sync-WslRootFileSystem
                Should -Invoke -CommandName Get-DockerImageLayer -Times 0
            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Should return local root filesystems" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'docker.arch.rootfs.tar.gz' -ItemType File
            New-Item -Path $path -Name 'incus.alpine_3.19.rootfs.tar.gz'  -ItemType File
            try {
                $distributions = Get-WslRootFileSystem
                $distributions.Length | Should -Be 11
                (($distributions | Select-Object -ExpandProperty IsAvailableLocally) -contains $true) | Should -BeTrue

                $distributions = Get-WslRootFileSystem -State Synced
                $distributions.Length | Should -Be 2

                $distributions = Get-WslRootFileSystem -Type Builtin
                $distributions.Length | Should -Be 10

                $distributions = Get-WslRootFileSystem -Os Alpine
                $distributions.Length | Should -Be 3

                Get-WslRootFileSystem
                $distributions = @(Get-WslRootFileSystem -Type Incus)
                $distributions.Length | Should -Be 1

                $distributions = Get-WslRootFileSystem -Configured
                $distributions.Length | Should -Be 5
            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }

        }

        It "Should delete root filesystems" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'docker.alpine.rootfs.tar.gz' -ItemType File
            New-Item -Path $path -Name 'incus.alpine_3.19.rootfs.tar.gz'  -ItemType File
            try {
                $deleted = Remove-WslRootFileSystem alpine
                $deleted | Should -Not -BeNullOrEmpty
                $deleted.IsAvailableLocally | Should -BeFalse
                $deleted.State -eq [WslRootFileSystemState]::NotDownloaded | Should -BeTrue

                $nonDeleted = Remove-WslRootFileSystem alpine
                $nonDeleted | Should -BeNullOrEmpty

                $deleted = New-WslRootFileSystem "incus://alpine#3.19" | Remove-WslRootFileSystem
                $deleted | Should -Not -BeNullOrEmpty
                $deleted.IsAvailableLocally | Should -BeFalse

            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }

        }

        It "Should check root filesystem hashes" {
            $HASH_DATA = @"
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
$global:EmptyHash  docker.alpine.rootfs.tar.gz
"@

            Mock Sync-String { return $HASH_DATA }

            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'docker.alpine.rootfs.tar.gz' -ItemType File
            New-Item -Path $path -Name 'arch.rootfs.tar.gz'  -ItemType File
            try {
                $toCheck = New-WslRootFileSystem alpine
                $hashes = New-WslRootFileSystemHash 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/SHA256SUMS'
                $hashes.Algorithm | Should -Be 'SHA256'
                $hashes.Type | Should -Be 'sums'

                $hashes.Retrieve()
                $hashes.Hashes.Count | Should -Be 2

                $digest = $hashes.DownloadAndCheckFile($toCheck.Url, $toCheck.File)
                $digest | Should -Be $global:EmptyHash

                $toCheck = New-WslRootFileSystem ubuntu
                { $hashes.DownloadAndCheckFile("https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.1-x86_64.tar.gz", $toCheck.File) } | Should -Throw

                { $hashes.DownloadAndCheckFile([System.Uri]"http://example.com/unknown.rootfs.tar.gz", $toCheck.File) } | Should -Throw

            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Should check single hash" {
            $HASH_DATA = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

            Mock Sync-String { return $HASH_DATA }

            $path = [WslRootFileSystem]::BasePath.FullName
            $url = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            try {
                $toCheck = New-WslRootFileSystem alpine
                $hashes = New-WslRootFileSystemHash "$url.sha256" -Type 'single'
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
        # TODO:
        # - Test reload of distribution is hash has changed (both URL and docker)
        # - Test content of distribution metadata after download
    }
}
