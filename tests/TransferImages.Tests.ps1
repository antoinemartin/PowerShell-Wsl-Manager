using namespace System.IO;

# cSpell: ignore iknite yawsldocker

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
Param()

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
}


BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    Import-Module -Name (Join-Path $PSScriptRoot "TestUtils.psm1") -Force

    Set-MockPreference ($true -eq $Global:PesterShowMock)
}


Describe "WslImageTransfer" {
    BeforeAll {
        # The following test with actual images data
        # [DirectoryInfo] $OriginalBasePath = [WslImage]::BasePath
        # $OriginalBasePath.Parent
        # $TestBasePath = Join-Path -Path $OriginalBasePath.Parent.FullName -ChildPath "RootFSTest"
        # Write-Verbose "OriginalBasePath: $($OriginalBasePath.FullName)"
        # Write-Verbose "TestBasePath: $TestBasePath"
        # Remove-Item -Path $TestBasePath -Recurse -Force -ErrorAction SilentlyContinue
        # New-Item -Path $TestBasePath -ItemType Directory | Out-Null

        # # Copy images database from original location to test location
        # Get-ChildItem -Path $OriginalBasePath.FullName -Recurse -Include "images.db","docker.alpine*","*iknite*","*yawsldocker*" | ForEach-Object {
        #     $Destination = Join-Path -Path $TestBasePath -ChildPath $_.Name
        #     Write-Verbose "Copying $($_.FullName) to $Destination..."
        #     Copy-Item -Path $_.FullName -Destination $Destination -Force
        # }

        # [WslImage]::BasePath = [DirectoryInfo]::new($TestBasePath)
        # [WslImageDatabase]::DatabaseFileName =  [FileInfo]::new((Join-Path -Path $TestBasePath -ChildPath "images.db"))

        $WslRoot = Join-Path $TestDrive "Wsl"
        $ImageRoot = Join-Path $WslRoot "RootFS"
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
        [WslImageDatabase]::DatabaseFileName = [FileInfo]::new((Join-Path $ImageRoot "images.db"))

        # Mock the sources to avoid network access and control ImageSource db table content
        New-BuiltinSourceMock
        New-IncusSourceMock

        # Create some local image files to simulate existing local images
        New-MockImage -BasePath ([WslImage]::BasePath) `
            -Name "alpine" `
            -Distribution "Alpine" `
            -Release "3.22.1" `
            -Type "Builtin" `
            -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine#latest" `
            -LocalFileName "docker.alpine.rootfs.tar.gz" `
            -Configured $true `
            -Username "alpine" `
            -Uid 1000 `
            -ErrorAction Stop

        New-MockImage -BasePath ([WslImage]::BasePath) `
            -Name "alpine-base" `
            -Distribution "Alpine" `
            -Release "3.22.1" `
            -Type "Builtin" `
            -Url "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine-base#latest" `
            -LocalFileName "docker.alpine-base.rootfs.tar.gz" `
            -Configured $false `
            -Username "root" `
            -Uid 0 `
            -ErrorAction Stop

        New-MockImage -BasePath ([WslImage]::BasePath) `
            -Name "yawsldocker-alpine" `
            -Distribution "Alpine" `
            -Release "3.22.1" `
            -Type "Uri" `
            -Url "docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine#latest" `
            -LocalFileName "docker.yawsldocker-alpine.rootfs.tar.gz" `
            -Configured $true `
            -Username "alpine" `
            -Uid 1000 `
            -ErrorAction Stop

        # This one has no name and no Username
        New-MockImage -BasePath ([WslImage]::BasePath) `
            -Distribution "Alpine" `
            -Release "3.21.3" `
            -Type "Local" `
            -Url "file:///C:/Users/AntoineMartin/Downloads/iknite.rootfs.tar.gz" `
            -LocalFileName "iknite.rootfs.tar.gz" `
            -Configured $false `
            -ErrorAction Stop

        $SavedCurrentVersion = [WslImageDatabase]::CurrentVersion
        [WslImageDatabase]::CurrentVersion = 3
        Get-ChildItem -Path ([WslImage]::BasePath).FullName | Out-String | Write-Verbose -Verbose
    }

    AfterAll {
        InModuleScope -ModuleName Wsl-Manager {
            Close-WslImageDatabase
        }
        [WslImageDatabase]::CurrentVersion = $SavedCurrentVersion
        Get-ChildItem -Path $ImageRoot | Remove-Item -Force
    }


    It "Should transfer local images to database" {
        # Get the database instance (Will perform migration)
        $db = InModuleScope -ModuleName Wsl-Manager {
            Get-WslImageDatabase
        }
        $db.db | Should -Not -BeNull
        # Feed the database with built-in and incus sources
        Update-WslBuiltinImageCache -Type 'Builtin' | Out-Null
        Update-WslBuiltinImageCache -Type 'Incus' | Out-Null
        try {
            Write-Verbose "Opening database at $([WslImageDatabase]::DatabaseFileName)..."
            InModuleScope -ModuleName "Wsl-Manager" {
                param([WslImageDatabase] $db, [string] $TestBasePath)
                # Call the function to transfer local images to the database
                Move-LocalWslImage -Database $db.db -BasePath ([WslImage]::BasePath)
            } -ArgumentList $db, $TestBasePath
            # Verify that the local images have been transferred to the database
            $localImages = $db.GetLocalImages()
            $localImages | Should -Not -BeNullOrEmpty
            $localImages.Count | Should -BeGreaterOrEqual 2
            $localImages | ForEach-Object {
                Write-Verbose "Verifying local image: $($_)..."
                $_.State | Should -Be 'Synced'
                $_.LocalFileName | Should -Match '^[A-Fa-f0-9]{64}\.rootfs\.tar\.gz$'
                ($_.Type.ToString() -ne 'Builtin' -or $null -ne $_.ImageSourceId) | Should -BeTrue
                $_.Digest | Should -Match '^[A-Fa-f0-9]{64}$'
                (-not ($_.Url -match 'yawsldocker')) -or ($_.Type -eq 'Docker') | Should -BeTrue "Docker image should have type Docker $($_.Url) $($_.Type)"
            }
            $localImages | Format-Table Type,Name,Os,Release,Configured,Username,Uid,State,FileHash,Id,ImageSourceId -AutoSize | Out-String | Write-Verbose -Verbose
        } finally {
            $db.Close()
        }
    }
}
