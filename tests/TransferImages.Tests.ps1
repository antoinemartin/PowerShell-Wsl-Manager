using namespace System.IO;

# cSpell: ignore iknite yawsldocker

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]

Param()

BeforeDiscovery {
    # Loads and registers my custom assertion. Ignores usage of unapproved verb with -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot "TestAssertions.psm1") -DisableNameChecking
}


BeforeAll {
    Import-Module -Name (Join-Path $PSScriptRoot ".." "Wsl-Manager.psd1")
    Import-Module -Name (Join-Path $PSScriptRoot "TestUtils.psm1") -Force

    Set-MockPreference ($true -eq $Global:PesterShowMock)
    $Global:OriginalVerbosePreference = $VerbosePreference
    $VerbosePreference = "Continue"
}

AfterAll {
    $VerbosePreference = $Global:OriginalVerbosePreference
}

Describe "WslImageTransfer" {
    BeforeAll {
        [DirectoryInfo] $OriginalBasePath = [WslImage]::BasePath
        $OriginalBasePath.Parent
        $TestBasePath = Join-Path -Path $OriginalBasePath.Parent.FullName -ChildPath "RootFSTest"
        Write-Verbose "OriginalBasePath: $($OriginalBasePath.FullName)"
        Write-Verbose "TestBasePath: $TestBasePath"
        Remove-Item -Path $TestBasePath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $TestBasePath -ItemType Directory | Out-Null

        # Copy images database from original location to test location
        Get-ChildItem -Path $OriginalBasePath.FullName -Recurse -Include "images.db","docker.alpine*","*iknite*","*yawsldocker*" | ForEach-Object {
            $Destination = Join-Path -Path $TestBasePath -ChildPath $_.Name
            Write-Verbose "Copying $($_.FullName) to $Destination..."
            Copy-Item -Path $_.FullName -Destination $Destination -Force
        }

        [WslImage]::BasePath = [DirectoryInfo]::new($TestBasePath)
        [WslImageDatabase]::DatabaseFileName =  [FileInfo]::new((Join-Path -Path $TestBasePath -ChildPath "images.db"))
    }

    It "Should transfer local images to database" {
        # Open the database
        $db = [WslImageDatabase]::new()
        try {
            Write-Verbose "Opening database at $([WslImageDatabase]::DatabaseFileName)..."
            $db.Open()
            $db.db | Should -Not -BeNull
            InModuleScope -ModuleName "Wsl-Manager" {
                param([WslImageDatabase] $db, [string] $TestBasePath)
                # Call the function to transfer local images to the database
                Move-LocalWslImage -Database $db.db -BasePath $TestBasePath -Verbose
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
                $_.FileHash | Should -Match '^[A-Fa-f0-9]{64}$'
            }
            $localImages | Format-Table Type,Name,Os,Release,Configured,Username,Uid,State,FileHash,Id,ImageSourceId -AutoSize | Out-String | Write-Host
        } finally {
            $db.Close()
        }
    }
}
