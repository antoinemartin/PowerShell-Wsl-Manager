using namespace System.IO;

$extensions_regex = [regex]::new('((\.rootfs)?\.tar\.(g|x)z|wsl)$')
$architectures = @('amd64', 'x86_64', 'arm64', 'aarch64', 'i386', 'i686')

function New-WslImage2 {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'File', ValueFromPipeline = $true, Mandatory = $true)]
        [FileInfo]$File,
        [Parameter(ParameterSetName = 'Uri', ValueFromPipeline = $true, Mandatory = $true)]
        [Uri]$Uri
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $CandidateUri = [Uri]::new($Name, [UriKind]::RelativeOrAbsolute)
            if ($CandidateUri.IsAbsoluteUri) {
                $Uri = $CandidateUri
            } else {
                $CandidateFile = [FileInfo]::new($Name)
                if ($CandidateFile.Exists) {
                    $File = $CandidateFile
                }
            }
        }

        $result = $null
        if ($null -ne $Uri) {
            Write-Verbose "Creating WslImage by URI: $Uri ($($Uri.Scheme))"
            $result = Get-DistributionInformationFromUri -Uri $Uri
        } elseif ($null -ne $File) {
            Write-Verbose "Creating WslImage by file: $($File.FullName) (exists: $($File.Exists))"
            $result = Get-DistributionInformationFromFile -File $File
        } else {
            Write-Verbose "Creating WslImage by name: $Name"
            $result = Get-DistributionInformationFromName -Name $Name
        }
        if ($result) {
            $result = $result | ForEach-Object { [WslImage]::new($_) }
        }
        return $result
    }
}



function Get-DistributionInformationFromTarball {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [FileInfo]$File
    )

    $result = @{
        LocalFileName = $File.Name
        FileHash      = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
        Size          = $File.Length
        LastModified  = $File.LastWriteTimeUtc.ToString("o")
    }
    Write-Verbose "Getting distribution information from tarball: $($File.FullName)"

    try {
        $tempDir = New-TemporaryDirectory
        $tempDirPath = $tempDir.FullName
        Write-Verbose "Extracting Information from $($File.FullName)"
        try {
            Invoke-Tar -xf $File.FullName -C $tempDirPath etc/os-release usr/lib/os-release etc/wsl-configured etc/wsl.conf etc/passwd
        } catch {
            Write-Verbose "Warning: Failed to extract some files from the tarball: $($_.Exception.Message)"
        }

        if (-not (Test-Path -Path (Join-Path $tempDirPath 'etc/os-release'))) {
            if (Test-Path -Path (Join-Path $tempDirPath 'usr/lib/os-release')) {
                Move-Item -Path (Join-Path $tempDirPath 'usr/lib/os-release') -Destination (Join-Path $tempDirPath 'etc/os-release') -Force
            }
        }
        $osReleaseFile = Join-Path $tempDirPath 'etc/os-release'
        if (Test-Path $osReleaseFile) {
            Write-Verbose "Extracting Information from $osReleaseFile"
            $osRelease = Get-Content -Path (Join-Path $tempDirPath 'etc/os-release') -Raw -ErrorAction Stop
            $osRelease = $osRelease -replace '=\s*"(.*?)"', '=$1'
            $osRelease = $osRelease | ConvertFrom-StringData
            if ($osRelease.ID) {
                $result.Os = (Get-Culture).TextInfo.ToTitleCase($osRelease.ID)
            }
            if ($osRelease.BUILD_ID) {
                $result.Release = $osRelease.BUILD_ID
            }
            if ($osRelease.VERSION_ID) {
                $result.Release = $osRelease.VERSION_ID
            }
        } else {
            Write-Verbose "$osReleaseFile does not exist."
        }

        $wslConfiguredFile = Join-Path $tempDirPath 'etc/wsl-configured'
        if (Test-Path $wslConfiguredFile) {
            Write-Verbose "Found $wslConfiguredFile, setting Configured to true"
            $result.Configured = $true
            $result.Username = $result.Os.ToLower()
        }
        $wslConfFile = Join-Path $tempDirPath 'etc/wsl.conf'
        if (Test-Path $wslConfFile) {
            Write-Verbose "Extracting Information from $wslConfFile"
            $wslConf = Get-Content -Path $wslConfFile -ErrorAction Stop
            if ($wslConf) {
                $wslConf = ConvertFrom-IniFile -Lines $wslConf
                if ($wslConf['user'] -and $wslConf['user']['default']) {
                    $result.Username = $wslConf['user']['default']
                }
            }
        }
        if ($result.Username) {
            Write-Verbose "Username is set to $($result.Username). Extracting /etc/passwd to find UID."
            $passwdFile = Join-Path $tempDirPath 'etc/passwd'
            if (Test-Path $passwdFile) {
                $passwd = Get-Content -Path $passwdFile -ErrorAction Stop
                $userEntry = $passwd | Where-Object { $_ -match "^\s*$($result.Username):" }
                if ($userEntry) {
                    $fields = $userEntry -split ':'
                    if ($fields.Length -ge 3) {
                        $uid = $fields[2]
                        if ($uid -as [int]) {
                            $result.Uid = [int]$uid
                            Write-Verbose "Found UID $($result.Uid) for user $($result.Username)"
                        }
                    }
                } else {
                    Write-Verbose "No entry found for user $($result.Username) in /etc/passwd"
                }
            } else {
                Write-Verbose "$passwdFile does not exist."
            }
        }
    } catch {
        Write-Verbose "Failed to extract Distribution information: $($_.Exception.Message)"
    } finally {
        if ($tempDir -and $tempDir.Exists) {
            Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    return $result
}

function Get-DistributionInformationFromName {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name
    )

    $result = @{}

    if ($Name -match $extensions_regex) {
        $Name = $Name -replace $extensions_regex, ''
        # Remove any left rootfs or minirootfs string
        $Name = $Name -replace '(mini)?rootfs', ''
        # Remove any platform string
        $Name = $Name -replace '(amd64|x86_64|arm64|aarch64|i386|i686)', ''
        # replace multiple underscores or dashes with a single dash
        $Name = ($Name -replace '(_|-)+', '-').Trim('-')

        $VersionArray = $Name -split '-', 2
        if ($VersionArray.Length -ge 2) {
            $Name = $VersionArray[0]
            $result.Release = $VersionArray[1]
        }
        $TypeArray = $Name -split '\.', 2
        if ($TypeArray.Length -eq 2) {
            $Name = $TypeArray[1]
            switch ($TypeArray[0].ToLower()) {
                'docker'  { $result.Type = 'Docker' }
                'incus'   { $result.Type = 'Incus' }
                'builtin' { $result.Type = 'Builtin' }
            }
        }
        $result.Name = $Name
    } else {
        $result = Get-DistributionInformationFromUri -Uri ([Uri]::new("local://$Name"))
        if (-not $result) {
            $result = Get-DistributionInformationFromUri -Uri ([Uri]::new("builtin://$Name"))
        }
    }

    return $result
}

function Get-DistributionInformationFromDockerImage {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ImageName,

        [Parameter(Mandatory = $true)]
        [string]$Tag,

        [Parameter(Mandatory = $false)]
        [string]$Registry = "ghcr.io"
    )

    $result = @{
        Name     = $ImageName -replace '.*/', ''
        Type     = if ($ImageName -match '^antoinemartin/powerShell-wsl-manager/') { 'Builtin' } else { 'Docker' }
        Url      = "docker://$($Registry)/$($ImageName)#$($Tag)"
        Release  = $Tag
    }

    try {
        $manifest = Get-DockerImageManifest -Registry $Registry -Image $ImageName -Tag $Tag
        Write-Verbose "$($manifest | ConvertTo-Json -Depth 5)"
        $result.Release = $manifest.config.Labels['org.opencontainers.image.version']
        $result.Os = (Get-Culture).TextInfo.ToTitleCase($manifest.config.Labels['org.opencontainers.image.flavor'])
        if ($manifest.config.Labels.ContainsKey('com.kaweezle.wsl.rootfs.configured')) {
            $result.Configured = $manifest.config.Labels['com.kaweezle.wsl.rootfs.configured'] -eq 'true'
            Write-Verbose "Found Configured label: $($result.Configured)"
        }

        if ($manifest.config.Labels.ContainsKey('com.kaweezle.wsl.rootfs.uid')) {
            $result.Uid = [int]$manifest.config.Labels['com.kaweezle.wsl.rootfs.uid']
            Write-Verbose "Found UID label: $($result.Uid)"
        }

        if ($manifest.config.Labels.ContainsKey('com.kaweezle.wsl.rootfs.username')) {
            $result.Username = $manifest.config.Labels['com.kaweezle.wsl.rootfs.username']
            Write-Verbose "Found Username label: $($result.Username)"
        }

        $digest = $manifest.digest -split ':'
        if ($digest.Length -eq 2) {
            $result.FileHash = $digest[1].ToUpper()
            $result.LocalFileName = "$($result.FileHash).rootfs.tar.gz"
            $result.HashSource = @{
                Algorithm = $digest[0].ToUpper()
                Type      = 'docker'
                Mandatory = $false
            }
        }
        if ($manifest.size) {
            $result.Size = $manifest.size
        }
        if ($manifest.created) {
            $result.Created = (Get-Date $manifest.created).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-Verbose "Failed to get image labels from $($result.Url): ${$_.Exception.Message}"
    }

    return $result
}

function Get-DistributionInformationFromFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [FileInfo]$File
    )

    process {
        if (-not $File.Exists) {
            throw [WslImageException]::new("The specified file does not exist: $($File.FullName)")
        }

        # Steps:
        # 1. Get information from the tarball (/etc/os-release, /etc/wsl.conf)
        # 2. Compute a hash of the file for uniqueness
        # 3. Create a Hashtable with the information
        $result = @{
            Name          = 'unknown'
            Os            = 'Unknown'
            Release       = 'Unknown'
            Type          = 'Local'
            Url           = "file:///$($File.FullName -replace '\\', '/')"
            LocalFileName = $File.Name
            Configured    = $false
            Username      = 'root'
            Uid           = 0
            FileHash      = $null
            HashSource    = @{
                Algorithm = 'SHA256'
                Type      = 'sums'
                Mandatory = $false
            }
        }

        $additionalInfo = Get-DistributionInformationFromTarball -File $File
        foreach ($key in $additionalInfo.Keys) {
            $result[$key] = $additionalInfo[$key]
        }

        $fileNameInfo = Get-DistributionInformationFromName -Name $File.Name
        foreach ($key in $fileNameInfo.Keys) {
            $result[$key] = $fileNameInfo[$key]
        }

        return [PSCustomObject]$result
    }
}

function Get-DistributionInformationFromUrl {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Uri]$Uri
    )
    process {
        if (-not ($Uri.Scheme -in @('http', 'https'))) {
            throw "The specified URI must use http or https scheme: $($Uri.AbsoluteUri)"
        }

        # First get distribution information from the last segment of the URL
        $fileName = $Uri.Segments[-1]
        $result = Get-DistributionInformationFromName -Name $fileName
        if (-not $result.Release -or $result.Name -eq 'rootfs') {
            # Try to find the name and the release in the segments of the URL
            # if one segment contains a semver (3.22 or v3.22.1), the previous segment
            # is assumed to be the name.
            # if the segment is one of the known architectures, version and name come before
            Write-Verbose "Trying to extract Name and Release from URL segments"
            for ($i = $Uri.Segments.Length - 1; $i -gt 0; $i--) {
                # Write-Verbose "Checking segment: $($Uri.Segments[$i])"
                if ($Uri.Segments[$i] -match '^(v)?\d+(\.\d+){1,2}/?$') {
                    $result.Release = $Matches[0].TrimStart('v').TrimEnd('/')
                    $result.Name = $Uri.Segments[$i - 1].TrimEnd('/')
                    Write-Verbose "Extracted Name: $($result.Name), Release: $($result.Release)"
                    break
                }
                if ($Uri.Segments[$i] -replace '/$' -in $architectures) {
                    if ($i -ge 2) {
                        $result.Release = $Uri.Segments[$i - 1].TrimEnd('/')
                        $result.Name = $Uri.Segments[$i - 2].TrimEnd('/')
                        Write-Verbose "Extracted Name: $($result.Name), Release: $($result.Release)"
                        break
                    }
                }
            }
        }
        if (-not $result.Name) {
            throw "Could not determine the distribution name from the URL: $($Uri.AbsoluteUri)"
        }
        $result.Os = (Get-Culture).TextInfo.ToTitleCase($result.Name)
        $result.LocalFileName = $fileName
        $result.Url = $Uri.AbsoluteUri
        $result.Type = 'Uri'

        # Then try to fetch Digest information in a SHA256SUMS file in the same directory
        # $baseUri = $Uri.GetLeftPart([UriPartial]::Authority) + ($Uri.AbsolutePath -replace '[^/]+$', '')
        $sumsUri = [Uri]::new($Uri, "SHA256SUMS")
        Write-Verbose "Fetching SHA256SUMS from $($sumsUri.AbsoluteUri)"
        try {
            $sumsContent = Sync-String -Url $sumsUri
            # Write-Verbose "SHA256SUMS content:`n$sumsContent"
            $sumsLines = $sumsContent -split "`n"
            foreach ($line in $sumsLines) {
                if ($line -match "^\s*(?<hash>[a-fA-F0-9]{64})\s+(?<filename>.+)$") {
                    $hash = $matches['hash'].ToUpper()
                    $hashFilename = $matches['filename'].Trim()
                    if ($hashFilename -eq $fileName) {
                        $result.FileHash = $hash
                        $result.LocalFileName = "$hash.rootfs.tar.gz"
                        $result.HashSource = @{
                            Url       = $sumsUri.AbsoluteUri
                            Algorithm = 'SHA256'
                            Type      = 'sums'
                            Mandatory = $true
                        }
                        Write-Verbose "Found matching hash for $($fileName): $hash"
                        break
                    }
                }
            }
        } catch {
            Write-Verbose "Failed to fetch or parse SHA256SUMS from $($sumsUri.AbsoluteUri): ${$_.Exception.Message}"
        }

        if (-not $result.FileHash) {
            # Try the .sha256 file as a fallback
            $sha256Uri = [Uri]::new($Uri, "$fileName.sha256")
            Write-Verbose "Fetching SHA256 from $($sha256Uri.AbsoluteUri)"
            try {
                $sha256Content = Sync-String -Url $sha256Uri
                Write-Verbose "SHA256 content: $sha256Content"
                if ($sha256Content -match "^\s*(?<hash>[a-fA-F0-9]{64})") {
                    $hash = $matches['hash'].ToUpper()
                    $result.FileHash = $hash
                    $result.LocalFileName = "$hash.rootfs.tar.gz"
                    $result.HashSource = @{
                        Url       = $sha256Uri.AbsoluteUri
                        Algorithm = 'SHA256'
                        Type      = 'sidecar'
                        Mandatory = $true
                    }
                    Write-Verbose "Found SHA256 hash for $($fileName): $hash"
                }
            } catch {
                Write-Verbose "Failed to fetch or parse SHA256 from $($sha256Uri.AbsoluteUri): ${$_.Exception.Message}"
            }
        }
        return $result
    }
}

function Get-DistributionInformationFromUri {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Uri]$Uri
    )
    process {
        $result = @{}
        if ($Uri.Scheme -eq 'docker') {
            $Registry = $Uri.Host
            $ImageName = $Uri.AbsolutePath.TrimStart('/')
            $Tag = $Uri.Fragment.TrimStart('#')
            if (-not $Tag) {
                $Tag = 'latest'
            }
            $result = Get-DistributionInformationFromDockerImage -ImageName $ImageName -Tag $Tag -Registry $Registry
        } elseif ($Uri.Scheme -eq 'local') {
            $ImageName = $Uri.Host
            $Tag = $Uri.Fragment.TrimStart('#')
            if (-not $Tag) {
                $Tag = $null
            }
            $db = Get-WslImageDatabase
            if ($null -eq $db) {
                Write-Warning "No image database found. Cannot fetch local images."
            } else {
                Write-Verbose "Fetching local image from database: Name=$ImageName, Tag=$Tag"
                $result = $db.GetLocalImages("Name = @Name AND (@Tag IS NULL OR Release = @Tag)", @{ Name = $ImageName; Tag = $Tag })
                Write-Verbose "Found $($result) matching local images."
            }
        } elseif ($Uri.Scheme -in @('builtin', 'incus')) {
            $ImageName = $Uri.Host
            $Tag = $Uri.Fragment.TrimStart('#')
            if (-not $Tag) {
                $Tag = $null
            }
            $Type = if ($Uri.Scheme -eq 'builtin') { [WslImageType]::Builtin } else { [WslImageType]::Incus }
            Write-Verbose "Fetching builtin image: Type=$Type, Name=$ImageName, Tag=$Tag"
            Update-WslBuiltinImageCache -Type $Type | Out-Null
            [WslImageDatabase] $db = Get-WslImageDatabase
            $result = $db.GetImageSources("Type = @Type AND Name = @Name AND (@Tag IS NULL OR Release = @Tag)", @{ Type = $Type.ToString(); Name = $ImageName; Tag = $Tag })
        } elseif ($Uri.Scheme -eq 'ftp') {
            throw [WslImageException]::new("FTP scheme is not supported yet. Please use http or https.")
        } elseif ($Uri.Scheme -eq 'file') {
            $filePath = $Uri.LocalPath
            $file = [FileInfo]::new($filePath)
            if (-not $file.Exists) {
                throw [WslImageException]::new("The specified file does not exist: $filePath")
            }
            Write-Verbose "Fetching file from path: $filePath"
            $result = Get-DistributionInformationFromFile -File $file
        } elseif ($Uri.Scheme -in @('http', 'https')) {
            Write-Verbose "Fetching file from URL: $($Uri.AbsoluteUri)"
            $result = Get-DistributionInformationFromUrl -Uri $Uri
        } else {
            throw [WslImageException]::new("Unsupported URI scheme: $($Uri.Scheme). Supported schemes are http, https, ftp, and docker.")
        }
        return $result
    }
}
