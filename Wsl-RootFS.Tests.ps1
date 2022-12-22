
using namespace System.IO;
using module .\Wsl-RootFS.psm1

Update-TypeData -PrependPath .\Wsl-Manager.Types.ps1xml
Update-FormatData -PrependPath .\Wsl-Manager.Format.ps1xml

Describe "WslRootFileSystem" {
    BeforeAll {
        [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($(Join-Path $TestDrive "WslRootFS"))
    }
    InModuleScope "Wsl-RootFS" {
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
            $rootFs = [WslRootFileSystem]::new("alpine", $true)
            $rootFs.Os | Should -Be "Alpine"
            $rootFs.Release | Should -Be "3.17"
            $rootFs.AlreadyConfigured | Should -BeTrue
            $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
            $rootFs.IsAvailableLocally | Should -BeFalse
            $rootFs.Sync($false)
            $rootFs.IsAvailableLocally | Should -BeTrue
            $rootFs.LocalFileName | Should -Be "miniwsl.alpine.rootfs.tar.gz"
        }
    }
}
