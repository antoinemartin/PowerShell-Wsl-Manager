# Copyright 2022 Antoine Martin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

using namespace System.IO;

# cSpell: ignore Linq

function New-WslImage-MissingMetadata {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [DirectoryInfo] $BasePath = $null
    )
    if ($null -eq $BasePath) {
        $BasePath = [WslImage]::BasePath
    }
    if (-not $BasePath.Exists) {
        Write-Verbose "Base path $($BasePath.FullName) does not exist. Nothing to transfer."
        return
    }
    # First get tar.gz files and json files
    $tarFiles = $BasePath.GetFiles("*.rootfs.tar.gz", [SearchOption]::TopDirectoryOnly)
    $jsonFiles = $BasePath.GetFiles("*.rootfs.tar.gz.json", [SearchOption]::TopDirectoryOnly)
    $tarBaseNames = $tarFiles | ForEach-Object { $_.Name -replace '\.rootfs\.tar\.gz$', '' }
    $jsonBaseNames = $jsonFiles | ForEach-Object { $_.Name -replace '\.rootfs\.tar\.gz\.json$', '' }
    if ($tarBaseNames -and $jsonFiles) {
        if ($PSCmdlet.ShouldProcess("Metadata", "Creating missing metadata for local images.")) {
            [System.Linq.Enumerable]::Except([object[]]$tarBaseNames, [object[]]$jsonBaseNames) | ForEach-Object {
                Write-Verbose "No matching JSON file for tarball $_.rootfs.tar.gz. Creating metadata."
                $tarFile = [FileInfo]::new((Join-Path -Path $BasePath.FullName -ChildPath "$_.rootfs.tar.gz"))
                # This will extract information from filename as well as from the tarball itself
                $imageInfo = Get-DistributionInformationFromFile -File $tarFile
                Write-Verbose "Extracted image information: $($imageInfo | ConvertTo-Json -Depth 5)"
                # Save metadata to JSON file
                $imageInfo | Remove-NullProperties | ConvertTo-Json | Set-Content -Path "$($tarFile.FullName).json"
                Write-Verbose "Saved metadata to $($tarFile.FullName).json"
            }
        }
    }
}


function Move-LocalWslImage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateNotNull()]
        [SQLiteHelper] $Database,
        [DirectoryInfo] $BasePath = $null,
        [switch] $DoNotChangeFiles
    )

    if (-not $Database.IsOpen) {
        throw [WslManagerException]::new("The image database is not open.")
    }
    if ($null -eq $BasePath) {
        $BasePath = [WslImage]::BasePath
    }
    if (-not $BasePath.Exists) {
        Write-Verbose "Base path $($BasePath.FullName) does not exist. Nothing to transfer."
        return
    }
    # Build missing metadata for local images
    New-WslImage-MissingMetadata -BasePath $BasePath
    # Now we can loop through JSON files
    $jsonFiles = $BasePath.GetFiles("*.json", [SearchOption]::TopDirectoryOnly)
    if (-not $jsonFiles -or $jsonFiles.Count -eq 0) {
        Write-Verbose "No JSON files found in $($BasePath.FullName). Nothing to transfer."
        return
    }
    Write-Verbose "Found $($jsonFiles.Count) JSON files. Processing..."
    Get-WslImageSource -Source Builtin,Incus | Out-Null
    $query = $Database.CreateUpsertQuery("LocalImage")
    $querySource = $Database.CreateUpsertQuery("ImageSource", @('Id'))
    $jsonFiles | ForEach-Object {
        Write-Verbose "Processing file $($_.FullName)..."
        $image = Get-Content -Path $_.FullName | ConvertFrom-Json | Convert-PSObjectToHashtable
        $ImageFile = [FileInfo]::new((Join-Path -Path $BasePath.FullName -ChildPath $image.LocalFilename))
        $Size = if ($ImageFile.Exists) { $ImageFile.Length } else { $null }
        # fix Uid
        if ($image.ContainsKey('Uid') -and $image.ContainsKey('Username') -and $image.Uid -eq 0 -and $image.Username -ne 'root') {
            $image.Uid = 1000
        }
        $hash = if ($image.Hash) { $image.Hash } else { $image.HashSource }
        if (-not $image.Name) {
            Write-Verbose "No name found in JSON file. Trying to get information from filename $($_.BaseName)..."
            $fileNameInfo = Get-DistributionInformationFromName -Name $_.BaseName
            foreach ($key in $fileNameInfo.Keys) {
                $image[$key] = $fileNameInfo[$key]
            }
        }
        # Try to find the source
        $ImageSourceId = $null
        $LocalImageId = [Guid]::NewGuid().ToString()
        $Distribution = if ($image.ContainsKey('Distribution')) { $image.Distribution } else { $image.Os }
        $SourceIdQuery = "SELECT * FROM ImageSource WHERE Digest = @Digest;"
        $SourceIdParams = @{
            Digest = $image.FileHash
        }
        if ($image.Type -in [WslImageType]::Builtin, [WslImageType]::Incus) {
            Write-Verbose "Looking for existing image source $($image.Type)/$($Distribution)/$($image.Release)/$($image.Configured)..."
            $SourceIdQuery = "SELECT * FROM ImageSource WHERE Type = @Type AND Distribution = @Distribution AND Release = @Release AND Configured = @Configured;"
            $SourceIdParams = @{
                    Type = $image.Type.ToString()
                    Distribution = $Distribution
                    Release = $image.Release
                    Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                }
        } elseif ($image.Type -eq [WslImageType]::Uri) {
            Write-Verbose "Looking for existing image source on Uri $($image.Url)..."
            [System.Uri] $uri = $image.Url
            if ($uri.IsAbsoluteUri -and ($uri.Scheme -eq 'docker')) {
                Write-Verbose "Docker image detected. Converting to Docker type."
                $image.Type = [WslImageType]::Docker
            }
            $SourceIdQuery = "SELECT * FROM ImageSource WHERE Type = @Type AND Url = @Url;"
            $SourceIdParams = @{
                    Type = $image.Type.ToString()
                    Url = $image.Url
                }
        } else {
            Write-Verbose "Looking for existing image source with Digest $($image.FileHash)..."
        }
        $dt = $Database.ExecuteSingleQuery($SourceIdQuery, $SourceIdParams)
        if ($null -ne $dt -and $dt.Rows.Count -gt 0) {
            $ImageSourceId = $dt.Rows[0].Id
            Write-Verbose "Found existing image source with ID $($ImageSourceId)."
        } else {
            Write-Verbose "No existing image source found. Creating a new one."
            $ImageSourceId = [Guid]::NewGuid().ToString()
            $parametersSource = @{
                Id = $ImageSourceId
                Name = $image.Name
                Tags = if ($image.Tags) { $image.Tags -join ',' } else { $image.Release }
                Url = $image.Url
                Type = ($image.Type -as [WslImageType]).ToString()
                Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                Username = if ($image.ContainsKey('Username')) { $image.Username } elseif ($image.Configured) { $Distribution.ToLower() } else { 'root' }
                Uid = if ($image.ContainsKey('Uid')) { $image.Uid } elseif ($image.Configured) { 1000 } else { 0 }
                Distribution = $Distribution
                Release = $image.Release
                LocalFilename = $image.LocalFilename
                DigestSource = $hash.Type
                DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
                DigestUrl = $hash.Url
                Digest = $image.FileHash
                GroupTag = $LocalImageId
                Size = $Size
            }
            Write-Verbose "Inserting new image source with parameters:`n$($parametersSource | ConvertTo-Json -Depth 5)..."
            if ($PSCmdlet.ShouldProcess("ImageSource", "Insert new image source $($image.Name)")) {
                try {
                    $Database.ExecuteNonQuery($querySource, $parametersSource)
                } catch {  # nocov
                    throw [WslManagerException]::new("Failed to insert image source for local image $($image.Name) into the database. Error: $($_.Exception.Message)", $_.Exception)
                }
                $ImageSourceId = $parametersSource.Id
                Write-Verbose "Created new image source with ID $($ImageSourceId)."
            }
        }

        $newFileName = if ($hash.Algorithm -eq "SHA256") { "$($image.FileHash).rootfs.tar.gz" } else { "$($hash.Algorithm)_$($image.FileHash).rootfs.tar.gz" }
        $imageFile = Join-Path -Path $BasePath.FullName -ChildPath $_.BaseName
        $localFileExists = Test-Path -Path $imageFile
        $parameters = @{
            Id = $LocalImageId
            ImageSourceId = $ImageSourceId
            # CreationDate = $null
            # UpdateDate = $null
            Name = $image.Name
            Tags = if ($image.Tags) { $image.Tags -join ',' } else { $image.Release }
            Url = $image.Url
            Type = ($image.Type -as [WslImageType]).ToString()
            Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
            Username = if ($image.ContainsKey('Username')) { $image.Username } elseif ($image.Configured) { $Distribution.ToLower() } else { 'root' }
            Uid = if ($image.ContainsKey('Uid')) { $image.Uid } elseif ($image.Configured) { 1000 } else { 0 }
            Distribution = $Distribution
            Release = $image.Release
            LocalFilename = $newFileName
            DigestSource = $hash.Type
            DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
            DigestUrl = $hash.Url
            Digest = $image.FileHash
            State  = if ($localFileExists) { 'Synced' } else { 'NotDownloaded' }
            Size = $Size
        }
        Write-Verbose "Inserting or updating local image $($image.Name) into the database with parameters:`n$($parameters | ConvertTo-Json -Depth 5)..."
        if ($PSCmdlet.ShouldProcess("LocalImage", "Insert or update local image $($image.Name)")) {
            try {
                $Database.ExecuteNonQuery($query, $parameters)
            } catch {  # nocov
                throw [WslManagerException]::new("Failed to insert or update local image $($image.Name) into the database. Error: $($_.Exception.Message)", $_.Exception)
            }
            Write-Verbose "Inserted or updated local image $($image.Name) into the database."
        }

        if ($DoNotChangeFiles) {
            Write-Verbose "DoNotChangeFiles is set. Skipping file operations."
        } else {
            if (Test-Path -Path $imageFile) {
                if ($PSCmdlet.ShouldProcess("File", "Rename image file $imageFile to $newFileName")) {
                    $newFile = Join-Path -Path $BasePath.FullName -ChildPath $newFileName
                    if (-not (Test-Path -Path $newFile)) {
                        Write-Verbose "Renaming image file from $imageFile to $newFileName."
                        Rename-Item -Path $imageFile -NewName $newFileName -Force
                    } else {
                        Write-Verbose "Target file $newFile already exists. Deleting source file $imageFile."
                        Remove-Item -Path $imageFile -Force | Out-Null
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess("File", "Remove JSON file $($_.FullName)")) {
                Write-Verbose "Finished processing file $($_.FullName). Removing JSON file."
                Remove-Item -Path $_.FullName -Force | Out-Null
            }
        }
    }
}
