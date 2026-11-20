param([switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$game = Join-Path $root 'cstrike'
$hfs = Join-Path $game 'hfs'
$exe = Join-Path $hfs 'hfs.exe'
$started = $null
$ready = $false

try {
    $required = @(
        'addons/amxmodx/plugins/incom_case_drops.amxx',
        'addons/amxmodx/plugins/incom_newyear_gifts.amxx',
        'motd/newyear/index.html',
        'motd/newyear/catalog.js',
        'motd/newyear/reveal.js',
        'sound/incom/newyear/case_tick.wav'
    )
    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $game $path) -PathType Leaf)) {
            throw "Missing case file: $path"
        }
    }
    for ($index = 0; $index -lt 28; $index++) {
        $path = "motd/newyear/skins/$index.png"
        if (-not (Test-Path -LiteralPath (Join-Path $game $path) -PathType Leaf)) {
            throw "Missing case image: $path"
        }
    }

    $settings = Get-Content -LiteralPath (Join-Path $hfs 'config.yaml') -Raw
    $portMatch = [regex]::Match($settings, '(?m)^port:\s*(\d+)\s*$')
    if (-not $portMatch.Success) {
        throw 'Set the HTTP port in cstrike/hfs/config.yaml.'
    }
    $port = [int]$portMatch.Groups[1].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw "Invalid HFS HTTP port: $port"
    }
    $localBase = "http://127.0.0.1:$port/cstrike"
    $probe = "$localBase/motd/newyear/index.html"

    $process = Get-Process -Name hfs -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $exe } | Select-Object -First 1
    if (-not $process) {
        $started = Start-Process -FilePath $exe -WorkingDirectory $hfs -WindowStyle Hidden -PassThru
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    $lastError = 'No response'
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $probe -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ne 200 -or $response.Content -notmatch 'src="reveal.js') {
                throw 'Unexpected response for the case page'
            }
            $ready = $true
            break
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 400
        }
    }
    if (-not $ready) {
        throw "HFS did not serve $probe ($lastError)"
    }

    foreach ($path in @('motd/newyear/catalog.js','motd/newyear/reveal.js','motd/newyear/skins/27.png','sound/incom/newyear/case_tick.wav')) {
        $resource = Invoke-WebRequest -Uri "$localBase/$path" -UseBasicParsing -TimeoutSec 3
        if ($resource.StatusCode -ne 200 -or $resource.RawContentLength -eq 0) {
            throw "HFS did not serve $path"
        }
    }

    $hfsConfig = Get-Content -LiteralPath (Join-Path $hfs 'hfs.cfg') -Raw
    $configured = [regex]::Match($hfsConfig, '(?m)^\s*sv_downloadurl\s+"([^"]*)"').Groups[1].Value.Trim()
    if ($configured) {
        if ($configured -notmatch '^https?://[^"\s]+$') {
            throw 'sv_downloadurl in cstrike/hfs/hfs.cfg must be an HTTP(S) URL or an empty string.'
        }
        $clientBase = $configured.TrimEnd('/') + '/'
    } else {
        $lan = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object {
                $_.OperationalStatus -eq 'Up' -and
                ($_.NetworkInterfaceType -eq 'Ethernet' -or $_.NetworkInterfaceType -eq 'Wireless80211')
            } |
            ForEach-Object { $_.GetIPProperties() } |
            Where-Object { $_.GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.IPAddressToString -ne '0.0.0.0' } } |
            ForEach-Object { $_.UnicastAddresses } |
            Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.IPAddressToString -notlike '169.254.*' } |
            Select-Object -First 1
        $hostAddress = '127.0.0.1'
        if ($lan) {
            $hostAddress = $lan.Address.IPAddressToString
        }
        $clientBase = "http://${hostAddress}:$port/cstrike/"
    }

    if (-not $CheckOnly) {
        $runtime = Join-Path $hfs 'runtime-fastdl.cfg'
        Set-Content -LiteralPath $runtime -Encoding Ascii -Value ('sv_downloadurl "{0}"' -f $clientBase)
    }
    Write-Host "[FastDL] Case page and assets are ready. Client URL: $clientBase"
} catch {
    $ready = $false
    Write-Host "[FastDL] $($_.Exception.Message)"
    exit 1
} finally {
    if ($started -and ($CheckOnly -or -not $ready) -and -not $started.HasExited) {
        Stop-Process -Id $started.Id -ErrorAction SilentlyContinue
    }
}
