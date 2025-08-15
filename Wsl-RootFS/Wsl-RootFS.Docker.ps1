# Internal function to get authentication token
function Get-DockerAuthToken {
    param(
        [string]$Registry,
        [string]$Repository
    )

    try {
        Progress "Getting docker authentication token for registry $Registry and repository $Repository..."
        $tokenUrl = "https://$Registry/token?service=$Registry&scope=repository:$Repository`:pull"

        $tokenWebClient = New-Object System.Net.WebClient
        $tokenWebClient.Headers.Add("User-Agent", (Get-UserAgent))

        $tokenResponse = $tokenWebClient.DownloadString($tokenUrl)
        $tokenData = $tokenResponse | ConvertFrom-Json

        if ($tokenData.token) {
            return $tokenData.token
        }
        else {
            throw "No token received from authentication endpoint"
        }
    }
    catch {
        throw "Failed to get authentication token: $($_.Exception.Message)"
    }
    finally {
        if ($tokenWebClient) {
            $tokenWebClient.Dispose()
        }
    }
}

function Get-DockerImageLayerManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$AuthToken,

        [Parameter(Mandatory = $true)]
        [string]$ImageName,

        [Parameter(Mandatory = $true)]
        [string]$Tag,

        [Parameter(Mandatory = $false)]
        [string]$Registry = "ghcr.io"

        )

        if (-not $AuthToken) {
            $AuthToken = Get-DockerAuthToken -Registry $Registry -Repository $ImageName
        }

        # Create WebClient with proper headers
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", (Get-UserAgent))
        # $webClient.Headers.Add("Accept", "application/vnd.docker.distribution.manifest.v2+json")
        $webClient.Headers.Add("Accept", "application/vnd.oci.image.index.v1+json")
        $webClient.Headers.Add("Authorization", "Bearer $AuthToken")

        # Step 1: Get the image manifest
        $manifestUrl = "https://$Registry/v2/$ImageName/manifests/$Tag"
        Progress "Getting docker image manifest $Registry/$($ImageName):$Tag..."

        try {
            $manifestJson = $webClient.DownloadString($manifestUrl)
            $manifest = $manifestJson | ConvertFrom-Json
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw "Access denied to registry. The image may not exist or authentication failed."
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw "Image not found: $fullImageName`:$Tag"
            }
            else {
                throw "Failed to get manifest: $($_.Exception.Message)"
            }
        }

        # Step 2: Extract the amd manifest information
        if (-not $manifest.manifests -or $manifest.manifests.Count -eq 0) {
            throw "No manifests found in the image manifest"
        }

        $amdManifest = $manifest.manifests | Where-Object { $_.platform.architecture -eq 'amd64' }
        if (-not $amdManifest) {
            throw "No amd64 manifest found in the image manifest"
        }

        # replace the Accept header
        $webClient.Headers.Remove("Accept")
        $webClient.Headers.Add("Accept", $amdManifest.mediaType)

        $manifestUrl = "https://$Registry/v2/$ImageName/manifests/$($amdManifest.digest)"

        try {
            $manifestJson = $webClient.DownloadString($manifestUrl)
            $manifest = $manifestJson | ConvertFrom-Json | Convert-PSObjectToHashtable
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw "Access denied to registry. The image may not exist or authentication failed."
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw "Image not found: $fullImageName`:$Tag"
            }
            else {
                throw "Failed to get manifest: $($_.Exception.Message)"
            }
        }

        # Step 2: Extract layer information
        if (-not $manifest.layers -or $manifest.layers.Count -ne 1) {
            throw "The image should have exactly one layer"
        }

        # For images built FROM scratch with ADD, we expect typically one layer
        # Take the first (and usually only) layer
        $layer = $manifest.layers[0]

        $config = $manifest.config
        $configDigest = $config.digest

        $webClient.Headers.Remove("Accept")
        $webClient.Headers.Add("Accept", $config.mediaType)

        $configUrl = "https://$Registry/v2/$ImageName/blobs/$configDigest"

        try {
            $configJson = $webClient.DownloadString($configUrl)
            $config = $configJson | ConvertFrom-Json | Convert-PSObjectToHashtable
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw "Access denied to registry. The image may not exist or authentication failed."
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw "Image not found: $fullImageName`:$Tag"
            }
            else {
                throw "Failed to get manifest: $($_.Exception.Message)"
            }
        }

        $config.mediaType = $layer.mediaType
        $config.size = $layer.size
        $config.digest = $layer.digest

        return $config
}

<#
.SYNOPSIS
Downloads a Docker image layer from GitHub Container Registry (ghcr.io) as a tar.gz file.

.DESCRIPTION
This function downloads a Docker image from GitHub Container Registry by making HTTP requests to:
1. Get the image manifest
2. Ensure the image contains only one layer
3. Download the layer blob
4. Save it as a tar.gz file locally

This is specifically designed to work with images built by the build-rootfs-oci.yaml workflow,
which creates images with a single layer containing the root filesystem.

.PARAMETER ImageName
The name of the Docker image (e.g., "antoinemartin/powershell-wsl-manager/miniwsl-alpine")

.PARAMETER Tag
The tag of the image (e.g., "latest", "3.19.1", "2025.08.01")

.PARAMETER DestinationFile
The path where the downloaded layer should be saved as a tar.gz file

.PARAMETER Registry
The container registry URL. Defaults to "ghcr.io"

.EXAMPLE
Get-DockerImageLayer -ImageName "antoinemartin/powershell-wsl-manager/miniwsl-alpine" -Tag "latest" -DestinationFile "alpine.rootfs.tar.gz"
Downloads the latest alpine miniwsl image layer to alpine.rootfs.tar.gz

.EXAMPLE
Get-DockerImageLayer -ImageName "antoinemartin/powershell-wsl-manager/miniwsl-arch" -Tag "2025.08.01" -DestinationFile "arch.rootfs.tar.gz"
Downloads the arch miniwsl image with specific version tag

.NOTES
This function requires network access to the GitHub Container Registry.
The function assumes the Docker image has only one layer (typical for FROM scratch images with ADD).
#>
function Get-DockerImageLayer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ImageName,

        [Parameter(Mandatory = $true)]
        [string]$Tag,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFile,

        [Parameter(Mandatory = $false)]
        [string]$Registry = "ghcr.io"
    )

    # Internal function to format file size
    function Format-FileSize {
        param([long]$Bytes)

        if ($null -eq $Bytes) { $Bytes = 0 }

        $gb = [math]::pow(2, 30)
        $mb = [math]::pow(2, 20)
        $kb = [math]::pow(2, 10)

        if ($Bytes -gt $gb) {
            "{0:n1} GB" -f ($Bytes / $gb)
        }
        elseif ($Bytes -gt $mb) {
            "{0:n1} MB" -f ($Bytes / $mb)
        }
        elseif ($Bytes -gt $kb) {
            "{0:n1} KB" -f ($Bytes / $kb)
        }
        else {
            "$Bytes B"
        }
    }

    try {
        $fullImageName = "$Registry/$ImageName"
        Progress "Downloading Docker image layer from $fullImageName`:$Tag..."

        # Get authentication token
        $authToken = Get-DockerAuthToken -Registry $Registry -Repository $ImageName
        if (-not $authToken) {
            throw "Failed to retrieve authentication token for registry $Registry and repository $ImageName"
        }
        $layer = Get-DockerImageLayerManifest -Registry $Registry -ImageName $ImageName -Tag $Tag -AuthToken $authToken

        $layerDigest = $layer.digest
        $layerSize = $layer.size

        Information "Root filesystem size: $(Format-FileSize $layerSize). Digest $layerDigest. Downloading..."

        # Step 3: Download the layer blob
        $blobUrl = "https://$Registry/v2/$ImageName/blobs/$layerDigest"

        # Prepare destination file
        $destinationFileInfo = [System.IO.FileInfo]::new($DestinationFile)

        # Ensure destination directory exists
        if (-not $destinationFileInfo.Directory.Exists) {
            $destinationFileInfo.Directory.Create()
        }

        Start-Download $blobUrl $destinationFileInfo.FullName @{ Authorization = "Bearer $authToken" }

        Success "Successfully downloaded Docker image layer to $($destinationFileInfo.FullName)"

        # Verify the file was created and has content
        if ($destinationFileInfo.Exists) {
            $destinationFileInfo.Refresh()
            Information "Downloaded file size: $(Format-FileSize $destinationFileInfo.Length)"

            # Check file integrity (e.g., hash)
            $expectedHash = $layer.digest -split ":" | Select-Object -Last 1
            # $actualHash = Get-FileHash -Path $destinationFileInfo.FullName -Algorithm SHA256 | Select-Object -ExpandProperty Hash
            # if ($expectedHash -ne $actualHash) {
            #     throw "Downloaded file hash does not match expected hash. Expected: $expectedHash, Actual: $actualHash"
            # }
            return $expectedHash
        }
        else {
            throw "Failed to create destination file: $DestinationFile"
        }

    }
    catch {
        Write-Error "Failed to download Docker image layer: $($_.Exception.Message)"
        throw
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}
