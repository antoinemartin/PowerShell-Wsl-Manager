
# This function is here to mock the download in unit tests

function Sync-File {

    param(
        [System.Uri]$Url,
        [FileInfo]$File
    )
    Progress "Downloading $($Url)..."
    Start-Download $Url $File.FullName
}

function Invoke-FetchUrl {
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [System.Uri]$Uri,
        [Parameter(Position = 1, Mandatory = $false)]
        [hashtable]$Headers
    )
    process {
        $prevProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'
        try {
            $response = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing
            if ($response.Content -is [byte[]]) {
                return [System.Text.Encoding]::UTF8.GetString($response.Content)
            }
            return $response.Content
        } finally {
            $global:ProgressPreference = $prevProgressPreference
        }
    }
}


# Another function to mock in unit tests
function Sync-String {
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [System.Uri]$Url
    )
    process {
        $response = try { Invoke-WebRequest -Uri $Url -UseBasicParsing } catch {
            $_.Exception.Response
        }
        if ($response.StatusCode -ne 200) {
            return ""
        }
        if ($response.Content -is [byte[]]) {
            return [System.Text.Encoding]::UTF8.GetString($response.Content)
        }
        return $response.Content
    }
}

function Remove-NullProperties {
    <#
    .SYNOPSIS
        Removes null properties from an object.
    .DESCRIPTION
        This function recursively removes all null properties from a PowerShell object.
    .PARAMETER InputObject
        A PowerShell Object from which to remove null properties.
    .EXAMPLE
        $Object | Remove-NullProperties
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification='Internal use only')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline=$true)]
        [object]
        $InputObject
    )
    foreach ($object in $InputObject) {
        $objectType = $object.GetType()
        if ($object -is [string] -or $objectType.IsPrimitive -or $objectType.Namespace -eq 'System') {
            $object
            return
        }

        $NewObject = @{ }
        $Properties = if ($object -is [hashtable]) { $object.GetEnumerator() } else { $object.PSObject.Properties }
        $PropertyList = $Properties | Where-Object { $null -ne $_.Value }
        foreach ($Property in $PropertyList) {
            $NewObject[$Property.Name] = Remove-NullProperties $Property.Value
        }
        [PSCustomObject]$NewObject
    }
}

function Convert-PSObjectToHashtable {
  [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { Convert-PSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate -InputObject $collection
        }
        elseif ($InputObject -is [PSObject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = (Convert-PSObjectToHashtable $property.Value).PSObject.BaseObject
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}

function Invoke-Tar {
    [Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    $TempFile = New-TemporaryFile
    try {
        $result = & tar $Arguments 2>$TempFile
        if ($LASTEXITCODE -ne 0) {
            throw [WslManagerException]::new("tar command failed with exit code $LASTEXITCODE. Output: `n$(Get-Content $TempFile -Raw)")
        }
        return $result
    } finally {
        Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
    }
}


function ConvertFrom-IniFile {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Lines
    )
    $ini = @{}
    switch -regex ($Lines)
    {
        "^\[(.+)\]" # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
        }
        "(.+?)\s*=\s*(.*)" # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value.Trim('"')
        }
    }
    return $ini
}

function Invoke-GetFileHash {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Path,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$Algorithm = "SHA256"
    )
    $hash = Get-FileHash -Path $Path -Algorithm $Algorithm
    return $hash.Hash.ToUpper()
}
