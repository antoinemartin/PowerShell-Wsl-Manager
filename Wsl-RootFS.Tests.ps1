
using module .\Wsl-RootFS.psm1

Describe "WslRootFileSystem" {
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
    }
}
