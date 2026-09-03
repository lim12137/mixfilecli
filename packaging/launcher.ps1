# MixFile launcher with multi-NIC aggregation via dispatch (Rust dispatch-proxy).
# ASCII only on purpose: this file must parse correctly under Windows PowerShell 5.1.
# Requires Windows 10+ (uses Get-NetIPConfiguration / Get-NetTCPConnection).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$appExe = Join-Path $root 'MixFile\MixFile.exe'
$dispatchDir = Join-Path $root 'dispatch'
$dispatchExe = Get-ChildItem -Path $dispatchDir -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not (Test-Path $appExe)) { Write-Host "[ERROR] MixFile\MixFile.exe not found"; exit 1 }
if (-not $dispatchExe) { Write-Host "[ERROR] dispatch\dispatch.exe not found"; exit 1 }

function Test-Listening([int]$p) {
    return ($null -ne (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue))
}

# Windows (Hyper-V/WSL) reserves random TCP port blocks; binding inside them fails
# with os error 10013. Parse them once (locale-independent: leading numbers only).
$excludedRanges = @()
try {
    foreach ($line in (netsh interface ipv4 show excludedportrange protocol=tcp 2>$null)) {
        if ($line -match '^\s*(\d{2,5})\s+(\d{2,5})') {
            $excludedRanges += ,@([int]$Matches[1], [int]$Matches[2])
        }
    }
} catch { }

function Test-Excluded([int]$p) {
    foreach ($r in $excludedRanges) { if ($p -ge $r[0] -and $p -le $r[1]) { return $true } }
    return $false
}

$uplinks = @(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } |
    ForEach-Object { $_.IPv4Address.IPAddress } | Select-Object -Unique)

if ($uplinks.Count -lt 2) {
    Write-Host "[WARN] Found $($uplinks.Count) active uplink(s) ($($uplinks -join ', ')), need 2+ for aggregation."
    Write-Host "[WARN] Falling back to direct launch (no dispatch)."
    Start-Process -FilePath $appExe -WorkingDirectory (Split-Path $appExe)
    exit 0
}

Write-Host "[INFO] Active uplinks: $($uplinks -join ' + ')"
$addrArgs = @('start', '--ip', '127.0.0.1') + ($uplinks | ForEach-Object { "$_/1" })

# Try candidate ports until dispatch is actually listening.
$candidates = 17419, 27419, 11419, 19419, 21419, 10419
$bound = $false
$port = $null
foreach ($c in $candidates) {
    if (Test-Excluded $c) { Write-Host "[INFO] Port $c is in a Windows reserved range, skipping."; continue }
    if (Test-Listening $c) {
        Write-Host "[INFO] Port $c already listening (likely dispatch from a previous run), reusing."
        $bound = $true; $port = $c; break
    }
    Write-Host "[INFO] Trying dispatch on port $c ..."
    $proc = Start-Process -FilePath $dispatchExe -ArgumentList ($addrArgs + @('--port', "$c")) -WindowStyle Minimized -PassThru
    $ok = $false
    foreach ($i in 1..10) {
        Start-Sleep -Milliseconds 500
        if ($proc.HasExited) { break }
        if (Test-Listening $c) { $ok = $true; break }
    }
    if ($ok) { $bound = $true; $port = $c; break }
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Write-Host "[WARN] Port $c failed (reserved or blocked), trying next candidate."
}

if (-not $bound) {
    Write-Host "[ERROR] Could not start dispatch on any candidate port. Falling back to direct launch."
    Start-Process -FilePath $appExe -WorkingDirectory (Split-Path $appExe)
    exit 0
}

$env:JAVA_TOOL_OPTIONS = "-DsocksProxyHost=127.0.0.1 -DsocksProxyPort=$port"
Write-Host "[INFO] Starting MixFile through dispatch (127.0.0.1:$port)"
Start-Process -FilePath $appExe -WorkingDirectory (Split-Path $appExe)
Write-Host "[INFO] Web UI: http://localhost:4719 (if occupied, MixFile picks the next free port; check its console)"
