# MixFile launcher with multi-NIC aggregation via dispatch (Rust dispatch-proxy).
# ASCII only on purpose: this file must parse correctly under Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$appExe = Join-Path $root 'MixFile\MixFile.exe'
$dispatchDir = Join-Path $root 'dispatch'
$dispatchExe = Get-ChildItem -Path $dispatchDir -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
$port = 17419

if (-not (Test-Path $appExe)) { Write-Host "[ERROR] MixFile\MixFile.exe not found"; exit 1 }
if (-not $dispatchExe) { Write-Host "[ERROR] dispatch\dispatch.exe not found"; exit 1 }

$uplinks = @(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } |
    ForEach-Object { $_.IPv4Address.IPAddress } | Select-Object -Unique)

if ($uplinks.Count -lt 2) {
    Write-Host "[WARN] Found $($uplinks.Count) active uplink(s) ($($uplinks -join ', ')), need 2+ for aggregation."
    Write-Host "[WARN] Falling back to direct launch (no dispatch)."
    Start-Process -FilePath $appExe -WorkingDirectory (Split-Path $appExe)
    exit 0
}

$listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listening) {
    Write-Host "[INFO] dispatch already listening on port $port, reusing it."
} else {
    $addrArgs = @('start', '--ip', '127.0.0.1', '--port', "$port") + ($uplinks | ForEach-Object { "$_/1" })
    Write-Host "[INFO] Starting dispatch, dispatching across: $($uplinks -join ' + ')"
    Start-Process -FilePath $dispatchExe -ArgumentList $addrArgs -WindowStyle Minimized
    Start-Sleep -Seconds 2
}

$env:JAVA_TOOL_OPTIONS = "-DsocksProxyHost=127.0.0.1 -DsocksProxyPort=$port"
Write-Host "[INFO] Starting MixFile through dispatch (127.0.0.1:$port)"
Start-Process -FilePath $appExe -WorkingDirectory (Split-Path $appExe)
Write-Host "[INFO] Web UI: http://localhost:4719 (if occupied, MixFile picks the next free port; check its console)"
