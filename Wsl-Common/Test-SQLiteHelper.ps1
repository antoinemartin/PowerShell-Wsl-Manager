#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the pre-compiled SQLite helper functionality.

.DESCRIPTION
    This script validates that the pre-compiled SQLite helper works correctly
    and that the fallback to runtime compilation also functions properly.

.EXAMPLE
    .\Test-SQLiteHelper.ps1
    Runs the complete test suite.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PreCompiledHelper {
    Write-Host "Testing pre-compiled SQLite helper..." -ForegroundColor Yellow

    try {
        # Load the pre-compiled version
        $VerbosePreference = 'SilentlyContinue'
        . (Join-Path $PSScriptRoot 'SQLite.ps1')

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
        $binPath = Join-Path $PSScriptRoot 'bin'
        $binBackupPath = Join-Path $PSScriptRoot 'bin_backup'

        if (Test-Path $binPath) {
            Rename-Item $binPath $binBackupPath
        }

        try {
            # Load with fallback
            $VerbosePreference = 'SilentlyContinue'
            . (Join-Path $PSScriptRoot 'SQLite.ps1')

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
            if (Test-Path $binBackupPath) {
                if (Test-Path $binPath) {
                    Remove-Item $binPath -Recurse -Force
                }
                Rename-Item $binBackupPath $binPath
            }
        }

        return $success
    }
    catch {
        Write-Error "Runtime fallback test failed: $($_.Exception.Message)"
        return $false
    }
}

# Run the tests
Write-Host "SQLite Helper Test Suite" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

$preCompiledSuccess = Test-PreCompiledHelper
$fallbackSuccess = Test-RuntimeFallback

Write-Host "`nTest Results:" -ForegroundColor Cyan
Write-Host "Pre-compiled helper: $(if ($preCompiledSuccess) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($preCompiledSuccess) { 'Green' } else { 'Red' })
Write-Host "Runtime fallback: $(if ($fallbackSuccess) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($fallbackSuccess) { 'Green' } else { 'Red' })

if ($preCompiledSuccess -and $fallbackSuccess) {
    Write-Host "`n🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some tests failed!" -ForegroundColor Red
    exit 1
}
