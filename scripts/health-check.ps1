<#
.SYNOPSIS
    Confirm TradingView Desktop is reachable on the Chrome DevTools Protocol port.

.DESCRIPTION
    Three checks:
      1. A TradingView process is running.
      2. The configured TCP port is in the Listen state.
      3. http://localhost:<Port>/json/version responds with valid CDP JSON.

    Exits 0 if all three pass, 1 otherwise. Suitable for use in automation
    or as a precondition check before starting Claude Code.

.PARAMETER Port
    TCP port where the Chrome DevTools Protocol endpoint should be reachable.
    Defaults to 9222. Must match what TradingView was launched with.

.EXAMPLE
    PS> .\health-check.ps1
    [OK]   TradingView process running (PID 12480)
    [OK]   Port 9222 listening
    [OK]   CDP responsive — Browser: Chrome/124.0.0.0

.NOTES
    Author: Aleksandr Gvozdkov
    Requires: PowerShell 5.1+ or PowerShell 7
#>
[CmdletBinding()]
param(
    [int]$Port = 9222
)

$ErrorActionPreference = "Stop"
$failed = $false

# Check 1: process
$proc = Get-Process -Name "TradingView" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) {
    Write-Host "[OK]   TradingView process running (PID $($proc.Id))" -ForegroundColor Green
} else {
    Write-Host "[ERR]  No TradingView process found." -ForegroundColor Red
    Write-Host "       Launch with: .\launch-tradingview-debug.ps1" -ForegroundColor Yellow
    $failed = $true
}

# Check 2: port listening
$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listening) {
    Write-Host "[OK]   Port $Port listening" -ForegroundColor Green
} else {
    Write-Host "[ERR]  Port $Port is not in Listen state." -ForegroundColor Red
    Write-Host "       TradingView was likely launched without --remote-debugging-port." -ForegroundColor Yellow
    $failed = $true
}

# Check 3: CDP responds
if (-not $failed) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/json/version" -UseBasicParsing -TimeoutSec 5
        $json = $response.Content | ConvertFrom-Json
        $browser = if ($json.Browser) { $json.Browser } else { "unknown" }
        $ua      = if ($json.'User-Agent') { $json.'User-Agent' } else { "unknown" }
        Write-Host "[OK]   CDP responsive — Browser: $browser" -ForegroundColor Green
        Write-Host "       User-Agent: $ua" -ForegroundColor DarkGray
    } catch {
        Write-Host "[ERR]  Could not reach CDP at http://localhost:$Port/json/version" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
        $failed = $true
    }
}

if ($failed) { exit 1 } else { exit 0 }
