<#
.SYNOPSIS
    Launch TradingView Desktop with the Chrome DevTools Protocol debug port open.

.DESCRIPTION
    Resolves the TradingView Desktop executable via find-tradingview.ps1,
    stops any existing TradingView processes (unless -NoKill is specified),
    confirms the requested debug port is free, then starts TradingView with
    --remote-debugging-port=<Port>. Polls the port until it begins listening
    (up to 15 seconds).

.PARAMETER Port
    TCP port to bind the Chrome DevTools Protocol endpoint to. Defaults to 9222.
    Must match the port the MCP server expects.

.PARAMETER NoKill
    Skip stopping existing TradingView processes. Useful if you have already
    quit TradingView manually. Note: a running TradingView instance without
    the debug flag will not have CDP available.

.EXAMPLE
    PS> .\launch-tradingview-debug.ps1
    [INFO] Stopping existing TradingView processes...
    [INFO] Launching TradingView with debug port 9222...
    [OK]   CDP listening on 127.0.0.1:9222

.EXAMPLE
    PS> .\launch-tradingview-debug.ps1 -Port 9223 -NoKill

.NOTES
    Author: Aleksandr Gvozdkov
    Requires: PowerShell 5.1+ or PowerShell 7
#>
[CmdletBinding()]
param(
    [int]$Port = 9222,
    [switch]$NoKill
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$findScript = Join-Path $scriptDir "find-tradingview.ps1"

if (-not (Test-Path $findScript)) {
    Write-Host "[ERR]  find-tradingview.ps1 not found next to this script." -ForegroundColor Red
    exit 1
}

$exePath = & $findScript
if (-not $exePath -or -not (Test-Path $exePath)) {
    Write-Host "[ERR]  Could not resolve TradingView executable. See output above." -ForegroundColor Red
    exit 1
}

if (-not $NoKill) {
    $existing = Get-Process -Name "TradingView" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[INFO] Stopping existing TradingView processes..." -ForegroundColor Cyan
        $existing | Stop-Process -Force
        Start-Sleep -Seconds 2

        $still = Get-Process -Name "TradingView" -ErrorAction SilentlyContinue
        if ($still) {
            Write-Host "[ERR]  TradingView did not exit. Close it manually and retry." -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK]   Existing processes terminated." -ForegroundColor Green
    }
}

$conflict = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
if ($conflict) {
    $pid = $conflict[0].OwningProcess
    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    $name = if ($proc) { $proc.ProcessName } else { "unknown" }
    Write-Host "[ERR]  Port $Port is already in use by PID $pid ($name)." -ForegroundColor Red
    Write-Host "       Choose a different port: -Port 9223" -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Launching TradingView with debug port $Port..." -ForegroundColor Cyan
Start-Process -FilePath $exePath -ArgumentList "--remote-debugging-port=$Port"

$deadline = (Get-Date).AddSeconds(15)
$listening = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $listening = [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($listening) { break }
}

if ($listening) {
    Write-Host "[OK]   CDP listening on 127.0.0.1:$Port" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[ERR]  Port $Port did not open within 15 seconds." -ForegroundColor Red
    Write-Host "       TradingView may have launched without the debug flag." -ForegroundColor Yellow
    Write-Host "       Try closing it and rerunning this script." -ForegroundColor Yellow
    exit 1
}
