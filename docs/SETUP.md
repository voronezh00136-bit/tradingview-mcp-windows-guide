# Setup Guide

End-to-end setup for connecting Claude Code to TradingView Desktop on Windows. Six steps, ~15 minutes if everything cooperates.

## 1. Install Node.js

Download the LTS installer from [nodejs.org](https://nodejs.org/). During install, leave the "Add to PATH" option checked.

Verify:

```powershell
node --version
# v18.x.x or newer
npm --version
```

If `node` isn't recognized, close and reopen PowerShell. PATH changes don't propagate to existing shells.

## 2. Install Git

Download from [git-scm.com](https://git-scm.com/download/win). Defaults are fine.

Verify:

```powershell
git --version
```

## 3. Clone the upstream MCP server

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\tools" | Out-Null
cd "$env:USERPROFILE\.claude\tools"
git clone https://github.com/tradesdontlie/tradingview-mcp
cd tradingview-mcp
npm install
```

Note the absolute path to `src/server.js`. You'll need it for the next step. It will look like:

```
C:\Users\<you>\.claude\tools\tradingview-mcp\src\server.js
```

## 4. Register the MCP server in Claude Code

> **Critical:** the file is `~/.claude.json`, **not** `~/.claude/.mcp.json` as suggested by some upstream docs. Editing the wrong file is the single most common reason the MCP server "silently doesn't appear" in Claude Code.

Open `~/.claude.json` (create it if it doesn't exist):

```powershell
notepad $env:USERPROFILE\.claude.json
```

Add the `mcpServers` entry. Use [`claude.example.json`](claude.example.json) as a template. Replace `USERNAME` with your actual Windows username.

```json
{
  "mcpServers": {
    "tradingview-desktop": {
      "type": "stdio",
      "command": "node",
      "args": [
        "C:\\Users\\USERNAME\\.claude\\tools\\tradingview-mcp\\src\\server.js"
      ],
      "env": {}
    }
  }
}
```

> **Critical:** every backslash in a Windows path inside JSON must be doubled. `C:\Users\...` is invalid JSON. `C:\\Users\\...` is correct. A single missed backslash produces a `SyntaxError: Unexpected token` and the entire file is rejected.

If `~/.claude.json` already has other top-level keys, merge — don't replace.

Run the verifier:

```powershell
.\scripts\verify-config.ps1
```

## 5. Launch TradingView with debug port open

TradingView Desktop installs as an MSIX package under `C:\Program Files\WindowsApps\`. That directory is ACL-locked and not browsable in Explorer. You cannot find the executable by right-clicking the Start Menu shortcut.

**Option A — helper script (recommended):**

```powershell
.\scripts\launch-tradingview-debug.ps1
```

**Option B — manual:**

```powershell
$package = Get-AppxPackage *TradingView* | Select-Object -First 1
$exe = Join-Path $package.InstallLocation "TradingView.exe"
Start-Process $exe -ArgumentList "--remote-debugging-port=9222"
```

If multiple `.exe` files exist in `InstallLocation`, list them:

```powershell
Get-ChildItem $package.InstallLocation -Filter *.exe -Recurse
```

## 6. Verify

```powershell
.\scripts\health-check.ps1
```

Expected:

```
[OK]   TradingView process running (PID ...)
[OK]   Port 9222 listening
[OK]   CDP responsive — Browser: Chrome/...
```

Then open Claude Code and confirm the server is registered:

```
/mcp
```

You should see `tradingview-desktop`. Inside the session, run:

```
tv_health_check
```

The MCP server will respond with TradingView's connection state.

## What you can do now

Try prompts like:

- `tv_screenshot` — capture the active chart
- "Open BTCUSDT on the 1H chart and screenshot it"
- "Read the indicator values currently visible on the chart"
- "Switch to the 4H timeframe and add an EMA(50)"

The exact tool names and arguments come from the upstream server — see `tradingview-mcp/src/server.js` for the canonical list.

## Daily workflow

1. **Launch TradingView first** with the debug port (`launch-tradingview-debug.ps1`).
2. **Start Claude Code second.** It will spawn the MCP server as a child process via stdio.
3. The MCP server lives for the duration of the Claude Code session. When you exit, it exits. If TradingView crashes, restart it with the debug flag and restart Claude Code.
