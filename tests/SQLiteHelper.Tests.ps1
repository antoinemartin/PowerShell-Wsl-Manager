#!/usr/bin/env pwsh
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
Param(
    [Parameter()]
    [ValidateSet('PreCompiled', 'RuntimeFallback')]
    [string]$TestType
)

# If called with TestType parameter, execute individual test and exit
if ($TestType) {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Test-PreCompiledHelper {
        Write-Host "Testing pre-compiled SQLite helper..." -ForegroundColor Yellow

        try {
            # Load the pre-compiled version
            $VerbosePreference = 'SilentlyContinue'
            . (Join-Path $PSScriptRoot '..' 'Wsl-SQLite' 'SQLite.ps1')

            # Test basic functionality
            $db = [SQLiteHelper]::Open(':memory:')

            # Create a test table
            $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)")

            # Insert test data
            $params = @{ name = "Test Item" }
            $db.ExecuteNonQuery("INSERT INTO test (name) VALUES (:name)", $params)

            # Query the data
            $result = $db.ExecuteSingleQuery("SELECT id, name, created_at FROM test WHERE name = :name", $params)

            if ($result.Rows.Count -eq 1) {
                $row = $result.Rows[0]
                Write-Host "  ✓ Successfully created and queried data:" -ForegroundColor Green
                Write-Host "    ID: $($row['id'])" -ForegroundColor Gray
                Write-Host "    Name: $($row['name'])" -ForegroundColor Gray
                Write-Host "    Created: $($row['created_at'])" -ForegroundColor Gray
            } else {
                throw "Expected 1 row, got $($result.Rows.Count)"
            }

            # Test query generation functionality
            $insertQuery = $db.CreateInsertQuery("test")
            $updateQuery = $db.CreateUpdateQuery("test")
            $upsertQuery = $db.CreateUpsertQuery("test")

            if ($insertQuery -and $updateQuery -and $upsertQuery) {
                Write-Host "  ✓ Query generation methods work correctly" -ForegroundColor Green
            } else {
                throw "Query generation failed"
            }

            $db.Close()
            Write-Host "  ✓ Pre-compiled helper test passed!" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "Pre-compiled helper test failed: $($_.Exception.Message)"
            return $false
        }
    }

    function Test-RuntimeFallback {
        Write-Host "Testing runtime compilation fallback..." -ForegroundColor Yellow

        try {
            # Temporarily rename the bin directory to force fallback
            $sqliteRoot = Join-Path $PSScriptRoot '..' 'Wsl-SQLite'
            $binPath = Join-Path $sqliteRoot 'bin'
            $binBackupPath = Join-Path $sqliteRoot 'bin_backup'

            if (Test-Path $binPath) {
                Write-Host "  Moving bin directory to backup..." -ForegroundColor Gray
                Move-Item $binPath $binBackupPath -Force
            }

            try {
                # Load with fallback
                $VerbosePreference = 'SilentlyContinue'
                . (Join-Path $sqliteRoot 'SQLite.ps1')

                # Test basic functionality (note: runtime version doesn't use namespace)
                $db = [SQLiteHelper]::Open(':memory:')
                $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
                $db.ExecuteNonQuery("INSERT INTO test (name) VALUES (?)", @("Fallback Test"))

                $result = $db.ExecuteSingleQuery("SELECT COUNT(*) as count FROM test")
                $count = $result.Rows[0]['count']

                if ($count -eq 1) {
                    Write-Host "  ✓ Runtime fallback test passed!" -ForegroundColor Green
                    $success = $true
                } else {
                    Write-Error "Expected count=1, got count=$count"
                    $success = $false
                }

                $db.Close()
            }
            finally {
                # Restore the bin directory
                Write-Host "  Restoring bin directory..." -ForegroundColor Gray
                if (Test-Path $binBackupPath) {
                    if (Test-Path $binPath) {
                        Remove-Item $binPath -Recurse -Force
                    }
                    Move-Item $binBackupPath $binPath -Force
                }
            }

            return $success
        }
        catch {
            Write-Error "Runtime fallback test failed: $($_.Exception.Message)"
            return $false
        }
    }

    # Execute individual test based on TestType parameter
    switch ($TestType) {
        'PreCompiled' {
            $success = Test-PreCompiledHelper
            exit $(if ($success) { 0 } else { 1 })
        }
        'RuntimeFallback' {
            $success = Test-RuntimeFallback
            exit $(if ($success) { 0 } else { 1 })
        }
    }
}

# Pester test definitions
BeforeAll {
    # Only load SQLite.ps1 when running as Pester tests (not when called with TestType parameter)
    if (-not $TestType) {
        . (Join-Path $PSScriptRoot '..' 'Wsl-SQLite' 'SQLite.ps1')
    }
    # Get the current PowerShell executable path
    $currentPowerShell = if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core (pwsh)
        if ($IsWindows) {
            'pwsh.exe'
        } else {
            'pwsh'
        }
    } else {
        # Windows PowerShell
        'powershell.exe'
    }
}

Describe "SQLite.Helper" {
    Context "Cross-Process Test Execution" {
        It "Should pass pre-compiled SQLite helper test in separate process" {
            # Run pre-compiled test in separate process
            $process = Start-Process -FilePath $currentPowerShell -ArgumentList @('-File', $PSCommandPath, '-TestType', 'PreCompiled') -Wait -PassThru -NoNewWindow
            $process.ExitCode | Should -Be 0
        }

        It "Should pass runtime fallback test in separate process" {
            # Run runtime fallback test in separate process
            $process = Start-Process -FilePath $currentPowerShell -ArgumentList @('-File', $PSCommandPath, '-TestType', 'RuntimeFallback') -Wait -PassThru -NoNewWindow
            $process.ExitCode | Should -Be 0
        }
    }

    Context "Basic SQLite Helper Functionality" {
        It "Should load SQLite helper successfully" {
            { [SQLiteHelper] } | Should -Not -Throw
        }

        It "Should create and query in-memory database" {
            $db = [SQLiteHelper]::Open(':memory:')
            try {
                $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")
                $db.ExecuteNonQuery("INSERT INTO test (name) VALUES (?)", @("Test"))

                $result = $db.ExecuteSingleQuery("SELECT COUNT(*) as count FROM test")
                $result.Rows[0]['count'] | Should -Be 1
            }
            finally {
                $db.Close()
            }
        }

        It "Should support query generation methods" {
            $db = [SQLiteHelper]::Open(':memory:')
            try {
                $db.ExecuteNonQuery("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)")

                $insertQuery = $db.CreateInsertQuery("test")
                $insertQuery | Should -Not -BeNullOrEmpty
                $insertQuery | Should -Match "INSERT INTO.*test.*VALUES"

                $updateQuery = $db.CreateUpdateQuery("test")
                $updateQuery | Should -Not -BeNullOrEmpty
                $updateQuery | Should -Match "UPDATE.*test.*SET"

                $upsertQuery = $db.CreateUpsertQuery("test")
                $upsertQuery | Should -Not -BeNullOrEmpty
                $upsertQuery | Should -Match "INSERT INTO.*test.*ON CONFLICT"
            }
            finally {
                $db.Close()
            }
        }
    }
}
