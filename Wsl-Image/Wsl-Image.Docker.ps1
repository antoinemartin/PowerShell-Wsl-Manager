# Internal function to get authentication token
function Get-DockerAuthToken {
    param(
        [string]$Registry,
        [string]$Repository
    )

    try {
        Progress "Getting docker authentication token for registry $Registry and repository $Repository..."
        $tokenUrl = "https://$Registry/token?service=$Registry&scope=repository:$Repository`:pull"

        $Headers = @{
            "User-Agent" = (Get-UserAgent)
        }
        $tokenResponse = Invoke-WebRequest -Uri $tokenUrl -UseBasicParsing -Headers $Headers
        $tokenContent = $tokenResponse.Content
        $tokenData = $tokenContent | ConvertFrom-Json

        if ($tokenData.token) {
            return $tokenData.token
        }
        else {
            throw [WslImageDownloadException]::new("No token received from authentication endpoint")
        }
    }
    catch {
        if ($_.Exception -is [WslManagerException]) {
            throw $_.Exception
        }
        throw [WslImageDownloadException]::new("Failed to get authentication token: $($_.Exception.Message)", $_.Exception)
    }
}

function Get-DockerImageManifest {
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

        $Headers = @{
            "User-Agent" = (Get-UserAgent)
            Accept = "application/vnd.docker.distribution.manifest.v2+json"
            Authorization = "Bearer $AuthToken"
        }

        # Step 1: Get the image manifest
        $manifestUrl = "https://$Registry/v2/$ImageName/manifests/$Tag"
        Progress "Getting docker image manifest $($manifestUrl)..."

        try {
            $manifestResponse = Invoke-WebRequest -Uri $manifestUrl -Headers $Headers -UseBasicParsing
            $manifestJson = $manifestResponse.Content
            $manifest = $manifestJson | ConvertFrom-Json
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw [WslImageDownloadException]::new("Access denied to registry. The image may not exist or authentication failed.", $_.Exception)
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw [WslImageDownloadException]::new("Image not found: $fullImageName`:$Tag", $_.Exception)
            }
            else {
                throw [WslImageDownloadException]::new("Failed to get manifest: $($_.Exception.Message)", $_.Exception)
            }
        }

        # Step 2: Extract the amd manifest information
        if (-not $manifest.manifests -or $manifest.manifests.Count -eq 0) {
            throw [WslImageDownloadException]::new("No manifests found in the image manifest")
        }

        $amdManifest = $manifest.manifests | Where-Object { $_.platform.architecture -eq 'amd64' }
        if (-not $amdManifest) {
            throw [WslImageDownloadException]::new("No amd64 manifest found in the image manifest")
        }

        # replace the Accept header
        $Headers.Accept = $amdManifest.mediaType

        $manifestUrl = "https://$Registry/v2/$ImageName/manifests/$($amdManifest.digest)"

        try {
            $manifestResponse = Invoke-WebRequest -Uri $manifestUrl -Headers $Headers -UseBasicParsing
            $manifestJson = $manifestResponse.Content
            $manifest = $manifestJson | ConvertFrom-Json | Convert-PSObjectToHashtable
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw [WslImageDownloadException]::new("Access denied to registry. The image may not exist or authentication failed.", $_.Exception)
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw [WslImageDownloadException]::new("Image not found: $fullImageName`:$Tag", $_.Exception)
            }
            else {
                throw [WslImageDownloadException]::new("Failed to get manifest: $($_.Exception.Message)", $_.Exception)
            }
        }

        if (-not $manifest.layers) {
            throw [WslImageDownloadException]::new("The image layers are missing")
        }
        $layer = $manifest.layers

        # if $layer is an Array, test that is has only one element and get it
        if ($layer -is [Array]) {
            if ($layer.Count -ne 1) {
                throw [WslImageDownloadException]::new("The image should have exactly one layer")
            }
            $layer = $layer[0]
        }

        $config = $manifest.config
        $configDigest = $config.digest

        $Headers.Accept = $config.mediaType

        $configUrl = "https://$Registry/v2/$ImageName/blobs/$configDigest"

        try {
            $configResponse = Invoke-WebRequest -Uri $configUrl -Headers $Headers -UseBasicParsing
            $configJson = $configResponse.Content
            $config = $configJson | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty history, rootfs | Convert-PSObjectToHashtable
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw [WslImageDownloadException]::new("Access denied to registry. The image may not exist or authentication failed.", $_.Exception)
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw [WslImageDownloadException]::new("Image not found: $fullImageName`:$Tag", $_.Exception)
            }
            else {
                throw [WslImageDownloadException]::new("Failed to get manifest: $($_.Exception.Message)", $_.Exception)
            }
        }

        $config.mediaType = $layer.mediaType
        $config.size = $layer.size
        $config.digest = $layer.digest

        return $config
}

<#
.SYNOPSIS
Downloads a Docker image from GitHub Container Registry (ghcr.io) as a tar.gz file.

.DESCRIPTION
This function downloads a Docker image from GitHub Container Registry by making HTTP requests to:
1. Get the image manifest
2. Ensure the image contains only one layer
3. Download the layer blob
4. Save it as a tar.gz file locally

This is specifically designed to work with images built by the build-Image-oci.yaml workflow,
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
Get-DockerImage -ImageName "antoinemartin/powershell-wsl-manager/miniwsl-alpine" -Tag "latest" -DestinationFile "alpine.rootfs.tar.gz"
Downloads the latest alpine miniwsl image layer to alpine.rootfs.tar.gz

.EXAMPLE
Get-DockerImage -ImageName "antoinemartin/powershell-wsl-manager/miniwsl-arch" -Tag "2025.08.01" -DestinationFile "arch.rootfs.tar.gz"
Downloads the arch miniwsl image with specific version tag

.NOTES
This function requires network access to the GitHub Container Registry.
The function assumes the Docker image has only one layer (typical for FROM scratch images with ADD).
#>
function Get-DockerImage {
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


    try {
        $fullImageName = "$Registry/$ImageName"
        Progress "Downloading Docker image layer from $fullImageName`:$Tag..."

        # Get authentication token
        $authToken = Get-DockerAuthToken -Registry $Registry -Repository $ImageName
        if (-not $authToken) {
            throw [WslImageDownloadException]::new("Failed to retrieve authentication token for registry $Registry and repository $ImageName")
        }
        $layer = Get-DockerImageManifest -Registry $Registry -ImageName $ImageName -Tag $Tag -AuthToken $authToken

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
            #     throw [WslImageDownloadException]::new("Downloaded file hash does not match expected hash. Expected: $expectedHash, Actual: $actualHash")
            # }
            return $expectedHash
        }
        else {
            throw [WslImageDownloadException]::new("Failed to create destination file: $DestinationFile")
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
