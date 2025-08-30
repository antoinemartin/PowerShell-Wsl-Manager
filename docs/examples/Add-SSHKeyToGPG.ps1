<#
.SYNOPSIS
    Adds an SSH key to a GPG key for SSH authentication using GPG agent.

.DESCRIPTION
    The Add-SSHKeyToGPG cmdlet integrates an SSH private key with a GPG key to enable SSH authentication
    through the GPG agent. This allows you to use your GPG key for SSH operations while maintaining
    centralized key management through GPG.

    The cmdlet performs the following operations:
    1. Retrieves the SSH key fingerprint from the specified key file
    2. Adds the SSH key to the SSH agent if not already present
    3. Obtains the key grip from GPG agent
    4. Sets the Use-for-ssh attribute for the key grip
    5. Cleans up duplicate entries in the sshcontrol file
    6. Associates the SSH key with the specified GPG key

    This is particularly useful for developers who want to use hardware security keys or centralized
    GPG key management for SSH authentication.

.PARAMETER KeyPath
    Specifies the path to the SSH private key file that should be added to the GPG key.
    This parameter is mandatory and must point to a valid SSH private key file.

.PARAMETER GPGKeyID
    Specifies the GPG key ID (short ID, long ID, or fingerprint) to which the SSH key should be added.
    This parameter is mandatory and must reference an existing GPG key in your keyring.

.PARAMETER GPGKeySecret
    Specifies the passphrase for the GPG key as a SecureString object.
    This parameter is mandatory and is used to unlock the GPG key during the operation.

    To create a SecureString from user input:
    Read-Host -AsSecureString -Prompt "Enter GPG key passphrase"

    To create a SecureString from plain text:
    ConvertTo-SecureString "your-passphrase" -AsPlainText -Force

.EXAMPLE
    $passphrase = Read-Host -AsSecureString -Prompt "Enter GPG key passphrase"
    Add-SSHKeyToGPG -KeyPath "~/.ssh/id_rsa" -GPGKeyID "1234567890ABCDEF" -GPGKeySecret $passphrase

    This example adds the SSH key located at ~/.ssh/id_rsa to the GPG key with ID 1234567890ABCDEF,
    prompting the user for the GPG key passphrase securely.

.EXAMPLE
    $securePass = ConvertTo-SecureString "MyGPGPassphrase" -AsPlainText -Force
    Add-SSHKeyToGPG -KeyPath "C:\Users\User\.ssh\id_ed25519" -GPGKeyID "user@example.com" -GPGKeySecret $securePass

    This example adds an Ed25519 SSH key to a GPG key identified by email address, using a passphrase
    converted from plain text (not recommended for production use).

.EXAMPLE
    Add-SSHKeyToGPG -KeyPath ".\mykey" -GPGKeyID "ABCD1234" -GPGKeySecret $pass -WhatIf

    This example shows what would happen when adding the SSH key without actually performing the operation,
    using the -WhatIf parameter for testing.

.INPUTS
    None. This cmdlet does not accept pipeline input.

.OUTPUTS
    None. This cmdlet does not generate output objects. It provides informational messages about the operations performed.

.NOTES
    Prerequisites:
    - GPG (GNU Privacy Guard) must be installed and configured (gpg4win on Windows, gpg on Linux/Mac)
    - SSH client tools must be available (ssh-keygen, ssh-add)
    - GPG agent must be running and configured for SSH support (enable-ssh-support, enable-putty-support
      enable-win32-openssh-support in gpg-agent.conf)
    - The specified SSH key file must exist and be accessible
    - The specified GPG key must exist in your GPG keyring with a secret key available

    Security Considerations:
    - Always use SecureString for the GPG passphrase parameter
    - Ensure your GPG agent is properly configured with appropriate cache timeouts
    - The SSH key will be loaded into both SSH agent and GPG agent memory

    File Modifications:
    - This cmdlet may modify the sshcontrol file in your GPG configuration directory
    - Backup your GPG configuration before running if you have custom sshcontrol settings

    Troubleshooting:
    - If the key grip cannot be found, ensure the SSH key is properly formatted and accessible
    - If GPG operations fail, verify that gpg-agent is running and properly configured
    - Use -Verbose parameter to see detailed operation information

.LINK
    https://gnupg.org/documentation/manuals/gnupg/

.LINK
    https://wiki.gnupg.org/AgentForwarding

.COMPONENT
    GPG, SSH, Security

.ROLE
    Security, KeyManagement

.FUNCTIONALITY
    SSH key management, GPG integration, Authentication
#>

# cSpell: ignore keygen keyinfo keyattr pinentry sshcontrol sshcontrols keygrip
using namespace System.Diagnostics.Process

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$KeyPath,
    [Parameter(Mandatory=$true, Position=1)]
    [string]$GPGKeyID,
    [Parameter(Mandatory=$true, Position=2)]
    # To obtain the secret string, use: Read-Host -AsSecureString -Prompt "Enter GPG key passphrase"
    # Or convert from plain text: ConvertTo-SecureString "your-passphrase" -AsPlainText -Force
    [SecureString]$GPGKeySecret
)

# Get the Fingerprint of the SSH key
$SSHKeyFingerprint = (ssh-keygen -l -f $KeyPath) -split ' ' | Select-Object -Index 1
Write-Verbose "SSH Key Fingerprint: $SSHKeyFingerprint"

if ((ssh-add -l) -match $SSHKeyFingerprint) {
    Write-Information "SSH key with fingerprint $SSHKeyFingerprint is already added to SSH Agent. Skipping addition." -InformationAction Continue
} else {
    # Add the SSH key to the SSH Agent
    if ($PSCmdlet.ShouldProcess($KeyPath, "Add SSH key with fingerprint $SSHKeyFingerprint to SSH Agent")) {
        Write-Information "Adding SSH key $KeyPath to SSH Agent. KEEP PASSWORD BLANK!..." -InformationAction Continue
        ssh-add $KeyPath | Out-Null
    }
}

# Now retrieve the key grip of the key
$KeyGrip = gpg-connect-agent "KEYINFO --list --ssh-fpr" /bye | ForEach-Object { ,$_.Split(' ') } | Where-Object { $_[8] -eq $SSHKeyFingerprint } | ForEach-Object { $_[2] }
if (-not $KeyGrip) {
    throw "Key grip not found for SSH key fingerprint $SSHKeyFingerprint"
}
Write-Verbose "Key Grip: $KeyGrip"

# Set the key Use-for-ssh attribute
if ($PSCmdlet.ShouldProcess($KeyGrip, "Set Use-for-ssh attribute for key grip $KeyGrip")) {
    Write-Information "Setting Use-for-ssh attribute for key grip $KeyGrip..." -InformationAction Continue
    gpg-connect-agent "KEYATTR $KeyGrip Use-for-ssh: true" /bye | Out-Null
}

# Now clean sshcontrols
$SshControlFile = "$Env:APPDATA\gnupg\sshcontrol"
if (Test-Path $SshControlFile) {
    if ($PSCmdlet.ShouldProcess($SshControlFile, "Clean sshcontrol file to remove duplicates")) {
        $SshControlContent = Get-Content $SshControlFile -Raw
        if ($SshControlContent -notmatch $KeyGrip) {
            Write-Information "KeyGrip $KeyGrip not found in sshcontrol file. No cleaning needed." -InformationAction Continue
        } else {
            Write-Information "Cleaning sshcontrol file $SshControlFile of $SSHKeyFingerprint and $KeyGrip..." -InformationAction Continue
            $ReplaceRegex = "(?s)# RSA key added on: .*?`n# Fingerprints:.*?`n#\s+$($SSHKeyFingerprint).*?`n$KeyGrip\s+\d+\s*`n"
            Write-Verbose "Regex to remove:`n$ReplaceRegex"
            $SshControlContent = $SshControlContent -replace $ReplaceRegex, ''
            Write-Verbose "Updated sshcontrol content:`n$SshControlContent"
            $SshControlContent | Set-Content -NoNewline $SshControlFile
        }
    }
}

if ((gpg --list-keys --with-keygrip $GPGKeyID) -match $KeyGrip) {
    Write-Information "SSH key with key grip $KeyGrip is already associated with GPG key $GPGKeyID. Skipping addition." -InformationAction Continue
    return
} else {
    # Now add the SSH key to the GPG key
    if ($PSCmdlet.ShouldProcess($GPGKeyID, "Add SSH key with key grip $KeyGrip to GPG key $GPGKeyID")) {
        Write-Verbose "Adding SSH key with key grip $KeyGrip to GPG key $GPGKeyID..."

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = "gpg.exe"
        $process.StartInfo.Arguments =  '--status-fd 2', '--verbose', '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--command-fd', '0', '--expert', '--edit-key', $GPGKeyID, 'addkey'

        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.RedirectStandardInput = $true
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.ErrorDialog = $false
        $process.StartInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $process.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $process.EnableRaisingEvents = $true
        $process.StartInfo.EnvironmentVariables["LANG"] = "C" # Ensure consistent language for parsing

        # Use asynchronous reading to avoid hanging
        $outputBuilder = New-Object System.Text.StringBuilder
        $errorBuilder = New-Object System.Text.StringBuilder

        $outputEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
            param
            (
                [System.Object] $sender,
                [System.Diagnostics.DataReceivedEventArgs] $e
            )
            Write-Verbose "O[$($e.Data )]"
        } -MessageData $outputBuilder

        $errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {        param
            (
                [System.Object] $sender,
                [System.Diagnostics.DataReceivedEventArgs] $e
            )
            Write-Verbose "E[$($e.Data )]"
        } -MessageData $errorBuilder

        $process.Start() | Out-Null
        $process.StandardInput.AutoFlush = $true

        Write-Verbose "Process started. PID: $($process.Id)"

        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        # Wait a moment for initial output
        Start-Sleep -Milliseconds 500

        Write-Verbose "Sending commands to GPG..."
        # cSpell: ignore addkey
        $process.StandardInput.WriteLine([System.Net.NetworkCredential]::new("", $GPGKeySecret).Password)
        $process.StandardInput.WriteLine("13")
        $process.StandardInput.WriteLine($KeyGrip)
        $process.StandardInput.WriteLine("S")
        $process.StandardInput.WriteLine("E")
        $process.StandardInput.WriteLine("A")
        $process.StandardInput.WriteLine("Q")
        $process.StandardInput.WriteLine("1y")
        $process.StandardInput.WriteLine("save")
        $process.StandardInput.Close()

        $process.WaitForExit()

        # Clean up event handlers
        Unregister-Event -SourceIdentifier $outputEvent.Name
        Unregister-Event -SourceIdentifier $errorEvent.Name
    }
    Write-Information "SSH key with fingerprint $SSHKeyFingerprint added to GPG key $GPGKeyID." -InformationAction Continue
}
