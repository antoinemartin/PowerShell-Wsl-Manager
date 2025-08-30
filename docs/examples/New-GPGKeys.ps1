#!/usr/bin/env pwsh
# cSpell: ignore mainkey subkey subkeys

<#
.SYNOPSIS
    Creates GPG keys with main certification key and subkeys for signing, encryption, and authentication.

.DESCRIPTION
    This cmdlet generates a GPG key set consisting of:
    - A main certification key that never expires
    - A signing subkey that expires in 1 year (configurable)
    - An encryption subkey that expires in 1 year (configurable)
    - An authentication subkey that expires in 1 year (configurable)

.PARAMETER Name
    The name to associate with the GPG key.


.PARAMETER Email
    The email address to associate with the GPG key.

.PARAMETER KeyType
    The type of key to generate. Default is "rsa4096".

.PARAMETER ExpireMain
    Expiration time for the main key. Default is "0" (never expires).

.PARAMETER ExpireSub
    Expiration time for subkeys. Default is "1y" (1 year).

.EXAMPLE
    New-GPGKeys -Email "user@example.com" -Name "John Doe"
    Creates GPG keys for John Doe with default settings.

.EXAMPLE
    New-GPGKeys -Email "user@example.com" -Name "John Doe" -KeyType "rsa2048" -ExpireSub "2y"
    Creates GPG keys with RSA 2048-bit keys and subkeys that expire in 2 years.

.NOTES
    This cmdlet requires GPG to be installed and available in the system PATH.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$Email,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyType = "rsa4096",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpireMain = "0",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpireSub = "1y"
)

begin {
    Write-Verbose "Starting GPG key generation process"

    # Check if GPG is available
    try {
        $gpgVersion = gpg --version 2>$null
        if (-not $gpgVersion) {
            throw "GPG not found"
        }
        Write-Verbose "GPG is available"
    }
    catch {
        throw "GPG is not installed or not available in PATH. Please install GPG before running this cmdlet."
    }
}

process {
    try {
        $keyIdentity = "`"${Name} <${Email}>`""
        Write-Information "Creating GPG keys for: $keyIdentity" -InformationAction Continue

        if ($PSCmdlet.ShouldProcess($keyIdentity, "Generate GPG main key")) {
            # Generate main key (certification key)
            Write-Verbose "Generating main certification key..."
            $mainKeyArgs = @(
                "--batch"
                "--quick-generate-key"
                $keyIdentity
                $KeyType
                "cert"
                $ExpireMain
            )
            Write-Verbose "Running GPG command: gpg $($mainKeyArgs -join ' ')"

            $result = Start-Process -FilePath "gpg" -ArgumentList $mainKeyArgs -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -ne 0) {
                throw "Failed to generate main key. GPG exited with code $($result.ExitCode)`n$($result)"
            }
            Write-Verbose "Main key generated successfully"
        }

        # Get the fingerprint of the newly created key
        Write-Verbose "Retrieving main key fingerprint..."
        $fpOutput = gpg --list-keys --with-colons $Email 2>$null
        $mainKeyFpr = ($fpOutput | Where-Object { $_ -match "^fpr:" } | Select-Object -First 1) -replace "^fpr:+", "" -replace ":.*$", ""

        if (-not $mainKeyFpr) {
            throw "Could not retrieve fingerprint for the newly created key"
        }
        Write-Verbose "Main key fingerprint: $mainKeyFpr"

        if ($PSCmdlet.ShouldProcess($keyIdentity, "Add signing subkey")) {
            # Add subkey: Signing
            Write-Verbose "Adding signing subkey..."
            $signingKeyArgs = @(
                "--batch"
                "--quick-add-key"
                $mainKeyFpr
                $KeyType
                "sign"
                $ExpireSub
            )

            $result = Start-Process -FilePath "gpg" -ArgumentList $signingKeyArgs -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -ne 0) {
                throw "Failed to add signing subkey. GPG exited with code $($result.ExitCode)"
            }
            Write-Verbose "Signing subkey added successfully"
        }

        if ($PSCmdlet.ShouldProcess($keyIdentity, "Add encryption subkey")) {
            # Add subkey: Encryption
            Write-Verbose "Adding encryption subkey..."
            $encryptionKeyArgs = @(
                "--batch"
                "--quick-add-key"
                $mainKeyFpr
                $KeyType
                "encrypt"
                $ExpireSub
            )

            $result = Start-Process -FilePath "gpg" -ArgumentList $encryptionKeyArgs -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -ne 0) {
                throw "Failed to add encryption subkey. GPG exited with code $($result.ExitCode)"
            }
            Write-Verbose "Encryption subkey added successfully"
        }

        if ($PSCmdlet.ShouldProcess($keyIdentity, "Add authentication subkey")) {
            # Add subkey: Authentication
            Write-Verbose "Adding authentication subkey..."
            $authKeyArgs = @(
                "--batch"
                "--quick-add-key"
                $mainKeyFpr
                $KeyType
                "auth"
                $ExpireSub
            )

            $result = Start-Process -FilePath "gpg" -ArgumentList $authKeyArgs -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -ne 0) {
                throw "Failed to add authentication subkey. GPG exited with code $($result.ExitCode)"
            }
            Write-Verbose "Authentication subkey added successfully"
        }

        Write-Information "GPG key generation completed successfully!" -InformationAction Continue
        Write-Information "Main key expires: $(if ($ExpireMain -eq '0') { 'Never' } else { $ExpireMain })" -InformationAction Continue
        Write-Information "Subkeys expire: $ExpireSub" -InformationAction Continue

        # Return key information
        [PSCustomObject]@{
            Email = $Email
            Name = $Name
            KeyType = $KeyType
            MainKeyFingerprint = $mainKeyFpr
            MainKeyExpiration = $ExpireMain
            SubKeyExpiration = $ExpireSub
            Created = Get-Date
        }
    }
    catch {
        Write-Error "Failed to create GPG keys: $($_.Exception.Message)"
        throw
    }
}

end {
    Write-Verbose "GPG key generation process completed"
}
