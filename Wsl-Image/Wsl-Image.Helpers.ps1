
# This function is here to mock the download in unit tests

function Sync-File {

    param(
        [System.Uri]$Url,
        [FileInfo]$File
    )
    Progress "Downloading $($Url)..."
    Start-Download $Url $File.FullName
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
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
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
        $PropertyList = $object.PSObject.Properties | Where-Object { $null -ne $_.Value }
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
