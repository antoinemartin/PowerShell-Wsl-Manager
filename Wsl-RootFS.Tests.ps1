
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
            Mock Sync-File { Write-Host "####> Mock download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File}
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
            $rootFs.Release | Should -Be "3.17"
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
            try {
                $rootFs = [WslRootFileSystem]::new("alpine", $true)
                $rootFs.Os | Should -Be "Alpine"
                $rootFs.Release | Should -Be "3.17"
                $rootFs.AlreadyConfigured | Should -BeTrue
                $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
                $rootFs.IsAvailableLocally | Should -BeFalse
                $rootFs | Sync-WslRootFileSystem
                $rootFs.IsAvailableLocally | Should -BeTrue
                $rootFs.LocalFileName | Should -Be "miniwsl.alpine.rootfs.tar.gz"
                $rootFs.File.Exists | Should -BeTrue
                Should -Invoke -CommandName Sync-File -Times 1
    
            } finally {
                $path = [WslRootFileSystem]::BasePath.FullName
                Get-ChildItem -Path $path | Remove-Item
            }
        }

        It "Shouldn't download already present file" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name 'miniwsl.alpine.rootfs.tar.gz' -ItemType File
            try {
                $rootFs = [WslRootFileSystem]::new("alpine", $true)
                $rootFs.IsAvailableLocally | Should -BeTrue
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

                $distributions = Get-WslRootFileSystem -Type LXD
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
    }
}
