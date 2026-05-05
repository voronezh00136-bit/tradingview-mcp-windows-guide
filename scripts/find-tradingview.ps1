<#
.SYNOPSIS
    Locate the TradingView Desktop executable on Windows.

.DESCRIPTION
    TradingView Desktop installs as an MSIX package under
    C:\Program Files\WindowsApps\, which is ACL-locked and not browsable
    in Explorer. This script uses Get-AppxPackage to find the install
    location and returns the absolute path to TradingView.exe.

    If the package is not found, prints installation guidance.
    If the package is found but the .exe is missing from its expected
    location, lists candidate executables under InstallLocation.

.EXAMPLE
    PS> .\find-tradingview.ps1
    [INFO] Searching for TradingView Desktop package...
    [OK]   Found: C:\Program Files\WindowsApps\TradingView.Desktop_...\TradingView.exe

.NOTES
    Author: Aleksandr Gvozdkov
    Requires: PowerShell 5.1+ or PowerShell 7
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "[INFO] Searching for TradingView Desktop package..." -ForegroundColor Cyan

$package = Get-AppxPackage -Name "*TradingView*" | Select-Object -First 1

if (-not $package) {
    Write-Host "[ERR]  TradingView Desktop is not installed (no Appx package found)." -ForegroundColor Red
    Write-Host ""
    Write-Host "       Install TradingView Desktop from the Microsoft Store:" -ForegroundColor Yellow
    Write-Host "         https://apps.microsoft.com/detail/tradingview-desktop" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "       Or, if you have an installer-based version (.exe), this script" -ForegroundColor Yellow
    Write-Host "       cannot locate it automatically. Pass the path manually to" -ForegroundColor Yellow
    Write-Host "       launch-tradingview-debug.ps1 instead." -ForegroundColor Yellow
    exit 1
}

$exePath = Join-Path $package.InstallLocation "TradingView.exe"

if (Test-Path $exePath) {
    Write-Host "[OK]   Found: $exePath" -ForegroundColor Green
    return $exePath
}

Write-Host "[WARN] Package found but TradingView.exe not at the expected location." -ForegroundColor Yellow
Write-Host "       Package InstallLocation: $($package.InstallLocation)" -ForegroundColor Yellow
Write-Host "       Searching for .exe files under InstallLocation..." -ForegroundColor Yellow
Write-Host ""

$candidates = Get-ChildItem -Path $package.InstallLocation -Filter *.exe -Recurse -ErrorAction SilentlyContinue

if ($candidates) {
    Write-Host "       Candidate executables:" -ForegroundColor Yellow
    $candidates | ForEach-Object { Write-Host "         $($_.FullName)" -ForegroundColor Yellow }
} else {
    Write-Host "[ERR]  No executables found under InstallLocation. Reinstall TradingView Desktop." -ForegroundColor Red
}

exit 1
