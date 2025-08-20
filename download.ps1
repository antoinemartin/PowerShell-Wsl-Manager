# This code comes from scoop.sh And is licensed under the public domain.
# More information here: https://github.com/ScoopInstaller/Scoop

function Get-UserAgent() {
    return "Wsl-Manager/1.0 (+https://mrtn.me/PowerShell-Wsl-Manager/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}

function info($msg) { write-host "INFO  $msg" -f DarkGray }

function ftp_file_size($url) {
    $request = [net.FtpWebRequest]::Create($url)
    $request.Method = [net.WebRequestMethods+Ftp]::GetFileSize
    $request.GetResponse().ContentLength
}

function fileSize($length) {
    $gb = [math]::pow(2, 30)
    $mb = [math]::pow(2, 20)
    $kb = [math]::pow(2, 10)

    if ($length -gt $gb) {
        "{0:n1} GB" -f ($length / $gb)
    }
    elseif ($length -gt $mb) {
        "{0:n1} MB" -f ($length / $mb)
    }
    elseif ($length -gt $kb) {
        "{0:n1} KB" -f ($length / $kb)
    }
    else {
        if ($null -eq $length) {
            $length = 0
        }
        "$($length) B"
    }
}


# paths
function fileName($path) { split-path $path -leaf }
function strip_filename($path) { $path -replace [regex]::escape((fileName $path)) }

# Unlike url_filename which can be tricked by appending a
# URL fragment (e.g. #/dl.7z, useful for coercing a local filename),
# this function extracts the original filename from the URL.
function url_remote_filename($url) {
    $uri = (New-Object URI $url)
    $basename = Split-Path $uri.PathAndQuery -Leaf
    If ($basename -match ".*[?=]+([\w._-]+)") {
        $basename = $matches[1]
    }
    If (($basename -notlike "*.*") -or ($basename -match "^[v.\d]+$")) {
        $basename = Split-Path $uri.AbsolutePath -Leaf
    }
    If (($basename -notlike "*.*") -and ($uri.Fragment -ne "")) {
        $basename = $uri.Fragment.Trim('/', '#')
    }
    return $basename
}

function Start-Download {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [string]$url,
        [string]$to,
        [hashtable]$headers = @{}
    )
    $progress = [console]::IsOutputRedirected -eq $false -and
    $host.name -ne 'Windows PowerShell ISE Host'

    try {
        Invoke-Download -url $url -to $to -progress $progress -headers $headers
    }
    catch {
        $e = $_.exception
        if ($e.InnerException) { $e = $e.InnerException }
        throw $e
    }
}


# download with fileSize and progress indicator
function Invoke-Download ($url, $to, $progress, $headers = @{}) {
    $reqUrl = ($url -split '#')[0]
    $webRequest = [Net.WebRequest]::Create($reqUrl)
    if ($webRequest -is [Net.HttpWebRequest]) {
        $webRequest.UserAgent = Get-UserAgent
        $webRequest.Referer = strip_filename $url
        if ($url -match 'api\.github\.com/repos') {
            $webRequest.Accept = 'application/octet-stream'
            $webRequest.Headers['Authorization'] = "token $(Get-GitHubToken)"
        }
        if ($headers.Count -gt 0) {
            foreach ($header in $headers.GetEnumerator()) {
                $webRequest.Headers[$header.Key] = $header.Value
            }
        }
    }

    try {
        $webResponse = $webRequest.GetResponse()
    }
    catch [System.Net.WebException] {
        $exc = $_.Exception
        $handledCodes = @(
            [System.Net.HttpStatusCode]::MovedPermanently, # HTTP 301
            [System.Net.HttpStatusCode]::Found, # HTTP 302
            [System.Net.HttpStatusCode]::SeeOther, # HTTP 303
            [System.Net.HttpStatusCode]::TemporaryRedirect  # HTTP 307
        )

        # Only handle redirection codes
        $redirectRes = $exc.Response
        if ($handledCodes -notcontains $redirectRes.StatusCode) {
            throw $exc
        }

        # Get the new location of the file
        if ((-not $redirectRes.Headers) -or ($redirectRes.Headers -notcontains 'Location')) {
            throw $exc
        }

        $newUrl = $redirectRes.Headers['Location']
        info "Following redirect to $newUrl..."

        # Handle manual file rename
        if ($url -like '*#/*') {
            $null, $postfix = $url -split '#/'
            $newUrl = "$newUrl#/$postfix"
        }

        Invoke-Download -url $newUrl -to $to -progress$progress
        return
    }

    $total = $webResponse.ContentLength
    if ($total -eq -1 -and $webRequest -is [net.FtpWebRequest]) {
        $total = ftp_file_size($url)
    }

    if ($progress -and ($total -gt 0)) {
        [console]::CursorVisible = $false
        function Trace-DownloadProgress ($read) {
            Write-DownloadProgress -read $read -total $total -url $url
        }
    }
    else {
        write-host "Downloading $url ($(fileSize $total))..."
        function Trace-DownloadProgress {
            #no op
        }
    }

    try {
        $s = $webResponse.GetResponseStream()
        $fs = [io.file]::OpenWrite($to)
        $buffer = new-object byte[] 2048
        $totalRead = 0
        $sw = [diagnostics.stopwatch]::StartNew()

        Trace-DownloadProgress $totalRead
        while (($read = $s.read($buffer, 0, $buffer.length)) -gt 0) {
            $fs.write($buffer, 0, $read)
            $totalRead += $read
            if ($sw.ElapsedMilliseconds -gt 100) {
                $sw.restart()
                Trace-DownloadProgress $totalRead
            }
        }
        $sw.stop()
        Trace-DownloadProgress $totalRead
    }
    finally {
        if ($progress) {
            [console]::CursorVisible = $true
            write-host
        }
        if ($fs) {
            $fs.close()
        }
        if ($s) {
            $s.close();
        }
        $webResponse.close()
    }
}

function Format-DownloadProgress ($url, $read, $total, $console) {
    $filename = url_remote_filename $url

    # calculate current percentage done
    $p = [math]::Round($read / $total * 100, 0)

    # pre-generate LHS and RHS of progress string
    # so we know how much space we have
    $left = "$filename ($(fileSize $total))"
    $right = [string]::Format("{0,3}%", $p)

    # calculate remaining width for progress bar
    $minWidth = $console.BufferSize.Width - ($left.Length + $right.Length + 8)

    # calculate how many characters are completed
    $completed = [math]::Abs([math]::Round(($p / 100) * $minWidth, 0) - 1)

    # generate dashes to symbolize completed
    if ($completed -gt 1) {
        $dashes = [string]::Join("", ((1..$completed) | ForEach-Object { "=" }))
    }

    # this is why we calculate $completed - 1 above
    $dashes += switch ($p) {
        100 { "=" }
        default { ">" }
    }

    # the remaining characters are filled with spaces
    $spaces = switch ($dashes.Length) {
        $minWidth { [string]::Empty }
        default {
            [string]::Join("", ((1..($minWidth - $dashes.Length)) | ForEach-Object { " " }))
        }
    }

    "$left [$dashes$spaces] $right"
}

function Write-DownloadProgress ($read, $total, $url) {
    $console = $host.UI.RawUI;
    $left = $console.CursorPosition.X;
    $top = $console.CursorPosition.Y;
    $width = $console.BufferSize.Width;

    if ($read -eq 0) {
        $maxOutputLength = $(Format-DownloadProgress -url $url -read 100 -total $total -console $console).length
        if (($left + $maxOutputLength) -gt $width) {
            # not enough room to print progress on this line
            # print on new line
            write-host
            $left = 0
            $top = $top + 1
            if ($top -gt $console.CursorPosition.Y) { $top = $console.CursorPosition.Y }
        }
    }

    write-host $(Format-DownloadProgress -url $url -read $read -total $total -console $console) -noNewline
    [console]::SetCursorPosition($left, $top)
}
