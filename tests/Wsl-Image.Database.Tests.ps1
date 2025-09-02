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
        [WslImage]::BasePath = [DirectoryInfo]::new($ImageRoot)
        [WslImage]::BasePath.Create()
        [WslImageDatabase]::DatabaseFileName = [FileInfo]::new((Join-Path $ImageRoot "images.db"))

        # Mock builtins and Incus sources
        New-BuiltinSourceMock
        New-IncusSourceMock

        Set-MockPreference ($true -eq $Global:PesterShowMock)
    }

    AfterEach {
        Get-ChildItem -Path ([WslImage]::BasePath).FullName | Remove-Item -Force
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
            $db = [WslImageDatabase]::new()
            $db.Open()
            $db.UpdateIfNeeded()
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
        } finally {
            $db.Close()
        }
    }

    It "Should throw when operating on a closed db" {
        $db = [WslImageDatabase]::new()
        { $db.UpdateIfNeeded() } | Should -Throw
        { $db.CreateDatabaseStructure() } | Should -Throw
        $db.Open()
        { $db.Open() } | Should -Throw
    }
}
