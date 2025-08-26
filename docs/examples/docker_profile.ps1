
Import-Module Wsl-Manager

function Get-WslDockerInstance {
    [CmdletBinding()]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias("Name")]
        [string]$InstanceName = $Env:DOCKER_WSL
    )
    if (-not $InstanceName) {
        $InstanceName = "docker"
    }
    return Get-WslInstance -Name $InstanceName
}

function Start-WslDocker {
    [CmdletBinding()]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = "Name")]
        [Alias("Name")]
        [string]$InstanceName = $Env:DOCKER_WSL,
        [Parameter(Mandatory = $true, ParameterSetName = "Instance", ValueFromPipeline = $true)]
        [WslInstance]$Instance
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Instance = Get-WslDockerInstance -InstanceName $InstanceName
        }
        if ($PSCmdlet.ShouldProcess($Instance.Name, "Starting Docker in WSL instance")) {
            Invoke-WslInstance -Instance $Instance -User root /bin/sh "-c" "test -f /var/run/docker.pid || sudo -b sh -c 'dockerd -p /var/run/docker.pid -H unix:// -H tcp://0.0.0.0:2376 >/var/log/docker.log 2>&1'" | Out-Null
        }
        $Instance
    }
}

function Stop-WslDocker {
    [CmdletBinding()]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = "Name")]
        [Alias("Name")]
        [string]$InstanceName = $Env:DOCKER_WSL,
        [Parameter(Mandatory = $true, ParameterSetName = "Instance", ValueFromPipeline = $true)]
        [WslInstance]$Instance
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Instance = Get-WslDockerInstance -InstanceName $InstanceName
        }
        if ($PSCmdlet.ShouldProcess($Instance.Name, "Stopping Docker in WSL instance")) {
            Invoke-WslInstance -Instance $Instance -User root /bin/sh "-c" 'test -f /var/run/docker.pid && sudo kill `cat /var/run/docker.pid`' | Out-Null
        }
        $Instance
    }
}

function Invoke-WslDocker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    process {
        Start-WslDocker -Name $Env:DOCKER_WSL | Invoke-WslInstance -User root docker @Arguments
    }
}

Set-Alias -Name docker -Value Invoke-WslDocker
