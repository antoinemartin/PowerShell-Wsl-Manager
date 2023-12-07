
using namespace System.IO;
using module .\Wsl-RootFS.psm1

Update-TypeData -PrependPath .\Wsl-Manager.Types.ps1xml
Update-FormatData -PrependPath .\Wsl-Manager.Format.ps1xml


Describe "WslRootFileSystem" {
    BeforeAll {
        [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($(Join-Path $TestDrive "WslRootFS"))
        [WslRootFileSystem]::BasePath.Create()
    }
    InModuleScope "Wsl-RootFS" {
        BeforeEach {
            Mock Sync-File { Write-Host "####> Mock download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File }
        }
        
        It "should split LXD names" {
            $rootFs = [WslRootFileSystem]::new("lxd:almalinux:9", $false)
            $rootFs.Os | Should -Be "almalinux"
            $rootFs.Release | Should -Be "9"
            $rootFs.Type -eq [WslRootFileSystemType]::LXD | Should -BeTrue
        }
    
        It "Should fail on bad LXD names" {
            { [WslRootFileSystem]::new("lxd:badlinux:9") } | Should -Throw "Unknown LXD distribution with OS badlinux and Release 9. Check https://uk.lxd.images.canonical.com/images."
        }
        
        It "Should Recognize Builitn distributions" {
            $rootFs = [WslRootFileSystem]::new("alpine")
            $rootFs.Os | Should -Be "Alpine"
            $rootFs.Release | Should -Be "3.18"
            $rootFs.AlreadyConfigured | Should -BeFalse
            $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
            $rootFs.Url | Should -Be $([WslRootFileSystem]::Distributions['Alpine']['Url'])

            $rootFs = [WslRootFileSystem]::new("alpine", $true)
            $rootFs.AlreadyConfigured | Should -BeTrue
            $rootFs.Url | Should -Be $([WslRootFileSystem]::Distributions['Alpine']['ConfiguredUrl'])
        }

        It "Should split properly external URL" {
            $url = "https://kali.download/nethunter-images/current/rootfs/kalifs-amd64-minimal.tar.xz"
            $rootFs = [WslRootFileSystem]::new($url)
            $rootFs.Os | Should -Be "Kalifs"
            $rootFs.Release | Should -Be "unknown"
            $rootFs.AlreadyConfigured | Should -BeFalse
            $rootFs.Type -eq [WslRootFileSystemType]::Uri | Should -BeTrue
            $rootFs.Url | Should -Be $url

        }

        It "Should download distribution" {
            $HASHDATA = @"
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855  miniwsl.alpine.rootfs.tar.gz
"@
            
            Mock Sync-String { return $HASHDATA }
            [WslRootFileSystem]::HashSources.Clear()

            try {
                $rootFs = [WslRootFileSystem]::new("alpine", $true)
                $rootFs.Os | Should -Be "Alpine"
                $rootFs.Release | Should -Be "3.18"
                $rootFs.AlreadyConfigured | Should -BeTrue
                $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
                $rootFs.IsAvailableLocally | Should -BeFalse
                $rootFs | Sync-WslRootFileSystem
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.LocalFileName | Should -Be "miniwsl.alpine.rootfs.tar.gz"
                $rootFs.File.Exists | Should -BeTrue
                Should -Invoke -CommandName Sync-File -Times 1
    
            }
            finally {
                $path = [WslRootFileSystem]::BasePath.FullName
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Should download distribution by URL" {
            
            Mock Sync-String { throw  [System.Net.WebException]::new("test", 7) }
            [WslRootFileSystem]::HashSources.Clear()

            try {
                $rootFs = [WslRootFileSystem]::new("https://github.com/kaweezle/iknite/releases/download/v0.2.1/kaweezle.rootfs.tar.gz", $false)
                $rootFs.Os | Should -Be "kaweezle"
                $rootFs.Release | Should -Be "unknown"
                $rootFs.AlreadyConfigured | Should -BeFalse
                $rootFs.Type -eq [WslRootFileSystemType]::Uri | Should -BeTrue
                $rootFs.IsAvailableLocally | Should -BeFalse
                $rootFs | Sync-WslRootFileSystem
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.LocalFileName | Should -Be "kaweezle.rootfs.tar.gz"
                $rootFs.File.Exists | Should -BeTrue
                Should -Invoke -CommandName Sync-File -Times 1

                $rootFs = [WslRootFileSystem]::new("alpine", $true)
                { $rootFs | Sync-WslRootFileSystem } | Should -Throw "Error while loading distro *"
    
            }
            finally {
                $path = [WslRootFileSystem]::BasePath.FullName
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Shouldn't download already present file" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            $HASHDATA = @"
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855  miniwsl.alpine.rootfs.tar.gz
"@
            
            Mock Sync-String { return $HASHDATA }
            [WslRootFileSystem]::HashSources.Clear()

            try {
                $rootFs = [WslRootFileSystem]::new("alpine", $true)
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.FileHash | Should -Be 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
                $rootFs | Sync-WslRootFileSystem
                Should -Invoke -CommandName Sync-File -Times 0    
            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Should return local distributions" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            New-Item -Path $path -Name 'lxd.alpine_3.17.rootfs.tar.gz'  -ItemType File
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
                $distributions = @(Get-WslRootFileSystem -Type LXD)
                $distributions.Length | Should -Be 1

                $distributions = Get-WslRootFileSystem -Configured
                $distributions.Length | Should -Be 5
            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }
            
        }

        It "Should delete distributions" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            New-Item -Path $path -Name 'lxd.alpine_3.17.rootfs.tar.gz'  -ItemType File
            try {
                $deleted = Remove-WslRootFileSystem alpine -Configured
                $deleted | Should -Not -BeNullOrEmpty
                $deleted.IsAvailableLocally | Should -BeFalse
                $deleted.State -eq [WslRootFileSystemState]::NotDownloaded | Should -BeTrue

                $nondeleted = Remove-WslRootFileSystem alpine -Configured
                $nondeleted | Should -BeNullOrEmpty

                $deleted = New-WslRootFileSystem "lxd:alpine:3.17" | Remove-WslRootFileSystem
                $deleted | Should -Not -BeNullOrEmpty
                $deleted.IsAvailableLocally | Should -BeFalse

            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }
            
        }

        It "Should check hashes" {
            $HASHDATA = @"
0007d292438df5bd6dc2897af375d677ee78d23d8e81c3df4ea526375f3d8e81  archlinux.rootfs.tar.gz
E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855  miniwsl.alpine.rootfs.tar.gz
"@
            
            Mock Sync-String { return $HASHDATA }

            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            New-Item -Path $path -Name 'arch.rootfs.tar.gz'  -ItemType File
            try {
                $tocheck = New-WslRootFileSystem alpine -Configured
                $hashes = New-WslRootFileSystemHash 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/SHA256SUMS'
                $hashes.Algorithm | Should -Be 'SHA256'
                $hashes.Type | Should -Be 'sums'

                $hashes.Retrieve()
                $hashes.Hashes.Count | Should -Be 2

                $digest = $hashes.DownloadAndCheckFile($tocheck.Url, $tocheck.File)
                $digest | Should -Be E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855

                $tocheck = New-WslRootFileSystem arch
                { $hashes.DownloadAndCheckFile($tocheck.Url, $tocheck.File) } | Should -Throw

                $hashes.DownloadAndCheckFile([System.Uri]"http://example.com/unknown.rootfs.tar.gz", $tocheck.File) | Should -BeNullOrEmpty

            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Should check single hash" {
            $HASHDATA = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
            
            Mock Sync-String { return $HASHDATA }

            $path = [WslRootFileSystem]::BasePath.FullName
            $url = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            try {
                $tocheck = New-WslRootFileSystem alpine -Configured
                $hashes = New-WslRootFileSystemHash "$url.sha256" -Type 'single'
                $hashes.Algorithm | Should -Be 'SHA256'
                $hashes.Type | Should -Be 'single'

                $hashes.Retrieve()
                $hashes.Hashes.Count | Should -Be 1

                $hashes.DownloadAndCheckFile([System.Uri]$url, $tocheck.File) | Should -Not -BeNullOrEmpty

            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }

        }
    }
}
