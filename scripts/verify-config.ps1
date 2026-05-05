<#
.SYNOPSIS
    Verify the Claude Code MCP configuration for TradingView.

.DESCRIPTION
    Performs four checks against ~/.claude.json:
      1. The file exists. Warns if ~/.claude/.mcp.json is present, since
         that is the wrong file and a common source of "MCP server doesn't
         appear" issues.
      2. The file parses as valid JSON. Suggests fixes for common errors
         (single backslashes in Windows paths, trailing commas).
      3. The mcpServers.tradingview-desktop entry is present.
      4. The server.js path in args[0] resolves to a real file. If not,
         searches for candidate server.js files under the user's profile.

    Also runs a regex scan of the raw JSON for the single-backslash pattern
    common in copy-pasted Windows paths.

.EXAMPLE
    PS> .\verify-config.ps1
    [OK]   ~/.claude.json found
    [OK]   JSON parses cleanly
    [OK]   mcpServers.tradingview-desktop present
    [OK]   server.js exists at the configured path

.NOTES
    Author: Aleksandr Gvozdkov
    Requires: PowerShell 5.1+ or PowerShell 7
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$claudeJson = Join-Path $env:USERPROFILE ".claude.json"
$wrongPath  = Join-Path $env:USERPROFILE ".claude\.mcp.json"

# Check 1: file existence
if (-not (Test-Path $claudeJson)) {
    Write-Host "[ERR]  ~/.claude.json not found at: $claudeJson" -ForegroundColor Red
    if (Test-Path $wrongPath) {
        Write-Host "[WARN] But ~/.claude/.mcp.json exists. That is the WRONG file." -ForegroundColor Yellow
        Write-Host "       Claude Code reads ~/.claude.json, not ~/.claude/.mcp.json." -ForegroundColor Yellow
        Write-Host "       Move your mcpServers entry into ~/.claude.json." -ForegroundColor Yellow
    }
    exit 1
}
Write-Host "[OK]   ~/.claude.json found" -ForegroundColor Green

if (Test-Path $wrongPath) {
    Write-Host "[WARN] ~/.claude/.mcp.json also exists. Claude Code ignores it." -ForegroundColor Yellow
    Write-Host "       This file does nothing. You can delete it to avoid confusion." -ForegroundColor Yellow
}

# Check 2: JSON validity
$raw = Get-Content -Raw -Path $claudeJson
try {
    $config = $raw | ConvertFrom-Json
} catch {
    Write-Host "[ERR]  ~/.claude.json is not valid JSON." -ForegroundColor Red
    Write-Host "       Parser said: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "       Common causes on Windows:" -ForegroundColor Yellow
    Write-Host "         - Single backslashes in paths. Use C:\\Users\\... not C:\Users\..." -ForegroundColor Yellow
    Write-Host "         - Trailing comma after the last property in an object or array." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK]   JSON parses cleanly" -ForegroundColor Green

# Regex scan for single-backslash Windows path pattern
$singleBackslashPattern = '"[A-Z]:\\[^\\]'  # In string: matches "C:X" where X is not another backslash
if ($raw -match $singleBackslashPattern) {
    Write-Host "[WARN] Detected what looks like single-backslash Windows paths in the JSON." -ForegroundColor Yellow
    Write-Host "       JSON requires double backslashes. Example match nearby may be invalid." -ForegroundColor Yellow
}

# Check 3: mcpServers entry
if (-not $config.mcpServers) {
    Write-Host "[ERR]  No mcpServers block in ~/.claude.json." -ForegroundColor Red
    exit 1
}

$entry = $config.mcpServers.'tradingview-desktop'
if (-not $entry) {
    Write-Host "[ERR]  mcpServers.tradingview-desktop is not defined." -ForegroundColor Red
    $existing = $config.mcpServers.PSObject.Properties.Name
    if ($existing) {
        Write-Host "       Existing entries: $($existing -join ', ')" -ForegroundColor Yellow
    }
    Write-Host "       See docs/claude.example.json for a template." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK]   mcpServers.tradingview-desktop present" -ForegroundColor Green

# Check 4: server.js path resolution
$serverPath = $entry.args | Select-Object -First 1
if (-not $serverPath) {
    Write-Host "[ERR]  tradingview-desktop has no args. Expected args[0] to be the path to server.js." -ForegroundColor Red
    exit 1
}

if (Test-Path $serverPath) {
    Write-Host "[OK]   server.js exists at the configured path" -ForegroundColor Green
    Write-Host "       $serverPath" -ForegroundColor DarkGray
    exit 0
}

Write-Host "[ERR]  server.js does not exist at: $serverPath" -ForegroundColor Red
Write-Host "       Searching under $env:USERPROFILE for tradingview-mcp/src/server.js..." -ForegroundColor Yellow

$candidates = Get-ChildItem -Path $env:USERPROFILE -Filter "server.js" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "tradingview-mcp" }

if ($candidates) {
    Write-Host "       Candidate paths:" -ForegroundColor Yellow
    $candidates | ForEach-Object { Write-Host "         $($_.FullName)" -ForegroundColor Yellow }
    Write-Host "       Update ~/.claude.json with one of these (remember double backslashes)." -ForegroundColor Yellow
} else {
    Write-Host "       No tradingview-mcp/server.js found. Did you run 'git clone' and 'npm install'?" -ForegroundColor Yellow
    Write-Host "       See docs/SETUP.md step 3." -ForegroundColor Yellow
}

exit 1
