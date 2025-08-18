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
$global:TestFilename = 'docker.arch.rootfs.tar.gz'
$global:AlternateFilename = 'incus.alpine_3.19.rootfs.tar.gz'
$global:ETag = "MockedTag"
$global:ModifiedETag = "NewMockedTag"
$global:Builtins = @(
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "alpine-base"
        Os = "Alpine"
        Url = "docker://ghcr.io/antoinemartin/PowerShell-Wsl-Manager/alpine-base#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "3.22.1"
        Configured = $false
        Username = "root"
        Uid = 0
        LocalFilename = "docker.alpine-base.rootfs.tar.gz"
    },
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "alpine"
        Os = "Alpine"
        Url = "docker://ghcr.io/antoinemartin/PowerShell-Wsl-Manager/alpine#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "3.22.1"
        Configured = $true
        Username = "alpine"
        Uid = 1000
    }
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "arch-base"
        Os = "Arch"
        Url = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "2025.08.01"
        Configured = $false
        Username = "root"
        Uid = 0
        LocalFilename = "docker.arch-base.rootfs.tar.gz"
    },
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "arch"
        Os = "Arch"
        Url = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "2025.08.01"
        Configured = $true
        Username = "arch"
        Uid = 1000
        LocalFilename = "docker.arch.rootfs.tar.gz"
    }
)

$global:Incus = @(
    [PSCustomObject]@{
        Type = "Incus"
        Name = "almalinux"
        Os = "almalinux"
        Url = "https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20250816_23%3A08/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20250816_23%3A08/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "8"
        LocalFileName = "incus.almalinux_8.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "almalinux"
        Os = "almalinux"
        Url = "https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20250816_23%3A08/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20250816_23%3A08/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "9"
        LocalFileName = "incus.almalinux_9.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "alpine"
        Os = "alpine"
        Url = "https://images.linuxcontainers.org/images/alpine/3.19/amd64/default/20250816_13%3A00/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/alpine/3.19/amd64/default/20250816_13%3A00/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "3.19"
        LocalFileName = "incus.alpine_3.19.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "alpine"
        Os = "alpine"
        Url = "https://images.linuxcontainers.org/images/alpine/3.20/amd64/default/20250816_13%3A00/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/alpine/3.20/amd64/default/20250816_13%3A00/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "3.20"
        LocalFileName = "incus.alpine_3.20.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    }
)

$global:InvokeWebRequestUrlFilter = @'
$PesterBoundParameters.Uri -eq "{0}"
'@

$global:InvokeWebRequestUrlEtagFilter = @'
$PesterBoundParameters.Headers['If-None-Match'] -eq "{0}" -and $PesterBoundParameters.Uri -eq "{1}"
'@

Describe "WslRootFileSystem" {
    InModuleScope "Wsl-RootFS" {
        BeforeAll {
            $global:wslRoot = Join-Path $TestDrive "Wsl"
            $global:rootfsRoot = Join-Path $global:wslRoot "RootFS"
            [WslRootFileSystem]::BasePath = [DirectoryInfo]::new($global:rootfsRoot)
            [WslRootFileSystem]::BasePath.Create()

            function New-SourceMock([string]$SourceUrl, [PSCustomObject[]]$Values, [string]$Tag){

                Write-Host "Mocking source: $SourceUrl with ETag: $Tag"
                $Response = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
                $Response | Add-Member -MemberType NoteProperty -Name StatusCode -Value 200 -Force
                $ResponseHeaders = @{
                    'Content-Type' = 'application/json; charset=utf-8'
                    'ETag' = @($Tag)
                }
                $Response | Add-Member -MemberType NoteProperty -Name Headers -Value $ResponseHeaders -Force
                $Response | Add-Member -MemberType NoteProperty -Name Content -Value ($Values | ConvertTo-Json -Depth 10) -Force

                # Filter script block needs to be created on the fly to pass SourceUrl and Tag as
                # literal values. There is apparently no better way to do this. (see https://github.com/pester/Pester/issues/1162)
                # GetNewClosure() cannot be used because we need to access $PesterBoundParameters that is not in the closure and defined
                # at a higher scope.
                $block = [scriptblock]::Create($global:InvokeWebRequestUrlFilter -f $SourceUrl)

                # GetNewClosure() will create a closure that captures the current value of $Response
                Mock Invoke-WebRequest { return $Response }.GetNewClosure() -Verifiable -ParameterFilter $block

                $NotModifiedResponse = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
                $NotModifiedResponse | Add-Member -MemberType NoteProperty -Name StatusCode -Value 304 -Force
                $NotModifiedResponse | Add-Member -MemberType NoteProperty -Name Headers -Value $ResponseHeaders -Force
                $NotModifiedResponse | Add-Member -MemberType NoteProperty -Name Content -Value "" -Force

                $block = [scriptblock]::Create($global:InvokeWebRequestUrlEtagFilter -f @($Tag,$SourceUrl))

                $Exception = New-MockObject -Type System.Net.WebException
                $Exception | Add-Member -MemberType NoteProperty -Name Message -Value "Not Modified (Mock)" -Force
                $Exception | Add-Member -MemberType NoteProperty -Name InnerException -Value (New-MockObject -Type System.Exception) -Force
                $Exception | Add-Member -MemberType NoteProperty -Name Response -Value $NotModifiedResponse -Force

                Mock Invoke-WebRequest { throw $Exception }.GetNewClosure() -Verifiable -ParameterFilter $block
            }
        }
        BeforeEach {
            Mock Sync-File { Progress "Mock download to $($File.FullName)..."; New-Item -Path $File.FullName -ItemType File }
            Mock Get-DockerImageLayer {
                Progress "Mock getting Docker image layer for $($DestinationFile)..."
                New-Item -Path $DestinationFile -ItemType File | Out-Null
                return $global:EmptyHash
              }
            $WslRootFileSystemCacheFileCache.Clear()
        }
        AfterEach {
            Get-ChildItem -Path ([WslRootFileSystem]::BasePath).FullName | Remove-Item -Force
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
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ETag

            $rootFs = [WslRootFileSystem]::new("alpine-base")
            $rootFs.Os | Should -Be "Alpine"
            $rootFs.Release | Should -Be $global:Builtins[0].Release
            $rootFs.Configured | Should -BeFalse
            $rootFs.Type -eq [WslRootFileSystemType]::Builtin | Should -BeTrue
            $rootFs.Url | Should -Be $global:Builtins[0].Url
            $rootFs.Username | Should -Be "root"
            $rootFs.Uid | Should -Be 0

            $rootFs = [WslRootFileSystem]::new("alpine")
            $rootFs.Configured | Should -BeTrue
            $rootFs.Url | Should -Be $global:Builtins[1].Url
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

            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ETag

            try {
                $rootFs = [WslRootFileSystem]::new("alpine")
                $rootFs.Os | Should -Be "Alpine"
                $rootFs.Release | Should -Be $global:Builtins[1].Release
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
                $meta.Release | Should -Be "3.22.1"
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
            New-Item -Path $path -Name $global:TestFilename -ItemType File
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

        It "Should get values from builtin distributions" {
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ETag

            $path = [WslRootFileSystem]::BasePath.FullName
            $file = New-Item -Path $path -Name $global:TestFilename -ItemType File
            $fileSystem = [WslRootFileSystem]::new($file)
            $fileSystem | Should -BeOfType [WslRootFileSystem]
            $fileSystem.Name | Should -Be "arch"
            $fileSystem.Release | Should -Be $global:Builtins[3].Release
            $fileSystem.Configured | Should -BeTrue
        }

        It "Should return local root filesystems" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name $global:TestFilename -ItemType File
            New-Item -Path $path -Name $global:AlternateFilename  -ItemType File

            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ETag
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Incus] -Values $global:Incus -Tag $global:ETag
            try {
                $distributions = Get-WslRootFileSystem -Source Incus
                $distributions | Should -Not -BeNullOrEmpty
                $distributions.Length | Should -Be 4

                $distributions = Get-WslRootFileSystem -Source Builtins
                $distributions | Should -Not -BeNullOrEmpty
                $distributions.Length | Should -Be 4

                $distributions = Get-WslRootFileSystem -Source All
                $distributions.Length | Should -Be 8
                (($distributions | Select-Object -ExpandProperty IsAvailableLocally) -contains $true) | Should -BeTrue

                $distributions = Get-WslRootFileSystem -State Synced
                $distributions.Length | Should -Be 2

                $distributions = Get-WslRootFileSystem
                $distributions.Length | Should -Be 2

                $distributions = @(Get-WslRootFileSystem -Type Builtin)
                $distributions.Length | Should -Be 1

                $distributions = Get-WslRootFileSystem -Type Builtin -Source All
                $distributions.Length | Should -Be 4

                $distributions = Get-WslRootFileSystem -Os Alpine -Source All
                $distributions.Length | Should -Be 4

                Get-WslRootFileSystem
                $distributions = @(Get-WslRootFileSystem -Type Incus)
                $distributions.Length | Should -Be 1

                $distributions = @(Get-WslRootFileSystem -Configured)
                $distributions.Length | Should -Be 1
            }
            finally {
                Get-ChildItem -Path $path | Remove-Item
            }

        }

        It "Should delete root filesystems" {
            $path = [WslRootFileSystem]::BasePath.FullName
            New-Item -Path $path -Name $global:TestFilename -ItemType File
            New-Item -Path $path -Name $global:AlternateFilename  -ItemType File
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ETag
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Incus] -Values $global:Incus -Tag $global:ETag

            try {
                $distributions = Get-WslRootFileSystem
                $distributions | Should -Not -BeNullOrEmpty
                $distributions.Length | Should -Be 2

                $deleted = Remove-WslRootFileSystem arch
                $deleted | Should -Not -BeNullOrEmpty
                $deleted.IsAvailableLocally | Should -BeFalse
                $deleted.State  | Should -Be NotDownloaded

                $deleted = Remove-WslRootFileSystem alpine_*  # The name is alpine_3.19
                $deleted | Should -Not -BeNullOrEmpty
                $deleted.IsAvailableLocally | Should -BeFalse

                { Remove-WslRootFileSystem alpine  | Should -Throw }

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
        It "Should download and cache builtin root filesystems" {
            $root =  $global:rootfsRoot
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ETag

            Write-Host "First call"
            $distributions = Get-WslBuiltinRootFileSystem
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
            Write-Host "Cached call"
            $distributions = Get-WslBuiltinRootFileSystem
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Count | Should -Be $global:Builtins.Count

            Should -Invoke -CommandName Invoke-WebRequest -Times 0 -ParameterFilter {
                $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
            }

            # Now do it with synchronization after sleeping for one second
            Write-Host "Force sync call (1 second later)"
            Start-Sleep -Seconds 1
            $distributions = Get-WslBuiltinRootFileSystem -Sync
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Count | Should -Be $global:Builtins.Count

            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -ParameterFilter {
                $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
            }

            # test that builtins lastUpdate is newer
            $builtinsFile | Should -Exist
            $cache = $WslRootFileSystemCacheFileCache[[WslRootFileSystemSource]::Builtins]
            $cache.lastUpdate | Should -BeGreaterThan $firstLastUpdate

            # Force lastUpdate to yesterday to trigger a refresh
            $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
            $cache.lastUpdate = $currentTime - 86410
            $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $builtinsFile -Force

            Write-Host "Call one day later without changes"
            $distributions = Get-WslBuiltinRootFileSystem
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Count | Should -Be $global:Builtins.Count

            Should -Invoke -CommandName Invoke-WebRequest -Times 2 -ParameterFilter {
                $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
            }
            $builtinsFile | Should -Exist
            $cache = Get-Content -Path $builtinsFile | ConvertFrom-Json
            $cache.lastUpdate | Should -BeGreaterThan $firstLastUpdate -Because "Cache was refreshed so the lastUpdate should be greater."

            $cache = $WslRootFileSystemCacheFileCache[[WslRootFileSystemSource]::Builtins]
            $cache.lastUpdate = $currentTime - 86410
            $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $builtinsFile -Force
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Builtins] -Values $global:Builtins -Tag $global:ModifiedETag

            Write-Host "Call one day later (lastUpdate $($cache.lastUpdate), currentTime $($currentTime)) with changes (new etag)"
            $distributions = Get-WslBuiltinRootFileSystem
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Count | Should -Be $global:Builtins.Count

            Should -Invoke -CommandName Invoke-WebRequest -Times 2 -ParameterFilter {
                $PesterBoundParameters.Headers['If-None-Match'] -eq 'MockedTag'
            }
            $builtinsFile | Should -Exist
            $cache = Get-Content -Path $builtinsFile | ConvertFrom-Json
            $cache.lastUpdate | Should -BeGreaterThan $firstLastUpdate -Because "Cache was refreshed so the lastUpdate should be greater."
            $cache.etag | Should -Not -BeNullOrEmpty
            $cache.etag[0] | Should -Be "NewMockedTag"
        }

        It "Should download and cache incus root filesystems" {
            $root =  $global:rootfsRoot
            New-SourceMock -SourceUrl $WslRootFileSystemSources[[WslRootFileSystemSource]::Incus] -Values $global:Incus -Tag $global:ETag
            Write-Host "First call"
            $distributions = Get-WslBuiltinRootFileSystem -Source Incus
            $distributions | Should -Not -BeNullOrEmpty
            $distributions.Count | Should -Be $global:Incus.Count

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
}
