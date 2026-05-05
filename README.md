# TradingView MCP — Windows Setup Guide

Connect Claude Code to TradingView Desktop on Windows via the [Model Context Protocol](https://modelcontextprotocol.io/).

This repository is a wrapper around the upstream [tradesdontlie/tradingview-mcp](https://github.com/tradesdontlie/tradingview-mcp) project. It does not fork or replace the server — it adds a Windows-specific setup guide, helper scripts, and a troubleshooting playbook.

## Why this repo exists

The upstream guide works, but on Windows there are three silent failure modes that cost hours if you hit them blind:

1. **Wrong config path.** The upstream README points to `~/.claude/.mcp.json`. Claude Code on Windows actually reads `~/.claude.json`. Editing the wrong file leaves the MCP server invisible with no error.
2. **Single-backslash JSON.** Windows paths copied directly into JSON (`C:\Users\...`) are invalid. They must be double-escaped (`C:\\Users\\...`). The resulting `SyntaxError` is thrown silently inside Claude Code's MCP loader.
3. **TradingView's WindowsApps location.** TradingView Desktop installs as an MSIX package under `C:\Program Files\WindowsApps\`, which is ACL-locked and not browsable in Explorer. You cannot just right-click the shortcut to find the `.exe`.

This repo addresses all three with PowerShell helpers, an explicit config example, and a troubleshooting table.

## Links

- Upstream MCP server: [tradesdontlie/tradingview-mcp](https://github.com/tradesdontlie/tradingview-mcp)
- Claude Code documentation: [docs.claude.com/en/docs/claude-code/overview](https://docs.claude.com/en/docs/claude-code/overview)
- Model Context Protocol: [modelcontextprotocol.io](https://modelcontextprotocol.io/)

## Table of contents

- [What you get](#what-you-get)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Helper scripts](#helper-scripts)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## What you get

| File | Purpose |
|------|---------|
| `docs/SETUP.md` | Six-step end-to-end setup guide |
| `docs/TROUBLESHOOTING.md` | Diagnostic flow + ten common errors with fixes |
| `docs/ARCHITECTURE.md` | How the pieces connect (CDP, MCP, stdio) |
| `docs/CONTRIBUTING.md` | Scope and PR workflow |
| `docs/claude.example.json` | Minimal valid Claude Code config |
| `scripts/find-tradingview.ps1` | Locate the TradingView Desktop executable |
| `scripts/launch-tradingview-debug.ps1` | Launch TradingView with `--remote-debugging-port` |
| `scripts/verify-config.ps1` | Validate `~/.claude.json` for the MCP entry |
| `scripts/health-check.ps1` | Confirm CDP is reachable on the debug port |

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Claude Code | latest | [Installation](https://docs.claude.com/en/docs/claude-code/overview) |
| TradingView Desktop | any | Paid plan required for chart access via CDP |
| Node.js | 18 LTS or newer | `node --version` |
| Git | any | `git --version` |
| Windows | 10 or 11 | PowerShell 5.1+ or PowerShell 7 |

## Quick start

```powershell
# 1. Clone the upstream MCP server into the Claude Code tools directory
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\tools" | Out-Null
git clone https://github.com/tradesdontlie/tradingview-mcp "$env:USERPROFILE\.claude\tools\tradingview-mcp"
cd "$env:USERPROFILE\.claude\tools\tradingview-mcp"
npm install

# 2. Clone this repo for the helpers and docs
cd $env:USERPROFILE
git clone https://github.com/voronezh00136-bit/tradingview-mcp-windows-guide
cd tradingview-mcp-windows-guide

# 3. Register the MCP server
#    See docs/SETUP.md step 4. Use docs/claude.example.json as a template.
#    Important: edit ~/.claude.json, NOT ~/.claude/.mcp.json.

# 4. Launch TradingView with the debug port open
.\scripts\launch-tradingview-debug.ps1

# 5. Verify everything is wired up
.\scripts\verify-config.ps1
.\scripts\health-check.ps1
```

Then start Claude Code. The `tradingview-desktop` MCP server should appear in `/mcp`. Run `tv_health_check` from inside Claude Code to confirm.

## Helper scripts

All scripts live in `scripts/` and follow a consistent style: `[CmdletBinding()]`, `$ErrorActionPreference = "Stop"`, color-coded output.

### `find-tradingview.ps1`

Locates the TradingView Desktop executable inside `WindowsApps` using `Get-AppxPackage`.

```powershell
PS> .\scripts\find-tradingview.ps1
[INFO] Searching for TradingView Desktop package...
[OK]   Found: C:\Program Files\WindowsApps\TradingView.Desktop_...\TradingView.exe
```

### `launch-tradingview-debug.ps1`

Kills any running TradingView process and relaunches it with `--remote-debugging-port=9222`. Optional `-Port` and `-NoKill` parameters.

```powershell
PS> .\scripts\launch-tradingview-debug.ps1 -Port 9222
[INFO] Stopping existing TradingView processes...
[INFO] Launching TradingView with debug port 9222...
[OK]   CDP listening on 127.0.0.1:9222
```

### `verify-config.ps1`

Checks `~/.claude.json` exists, parses as valid JSON, contains the `tradingview-desktop` entry, and points at a real `server.js`.

```powershell
PS> .\scripts\verify-config.ps1
[OK]   ~/.claude.json found
[OK]   JSON parses cleanly
[OK]   mcpServers.tradingview-desktop present
[OK]   server.js exists at the configured path
```

### `health-check.ps1`

Confirms a TradingView process is running, the debug port is listening, and CDP responds at `/json/version`.

```powershell
PS> .\scripts\health-check.ps1
[OK]   TradingView process running (PID 12480)
[OK]   Port 9222 listening
[OK]   CDP responsive — Browser: Chrome/124.0.0.0
```

## Troubleshooting

The five most common failures. Full table with ten cases in [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `tv_health_check` returns nothing | TradingView launched without `--remote-debugging-port` | Use `launch-tradingview-debug.ps1` |
| MCP server not listed in Claude Code | Edited `.claude/.mcp.json` instead of `.claude.json` | Move config to `~/.claude.json` |
| `SyntaxError: Unexpected token` | Single-backslash paths in JSON | Double-escape: `C:\\Users\\...` |
| `node: command not found` | Node not on PATH after install | Restart shell, or reinstall with "Add to PATH" |
| `CDP connection failed` | Port not open or wrong port number | Run `health-check.ps1` to confirm |

## Architecture

```
┌──────────────────────┐     CDP / WebSocket      ┌──────────────────────┐
│  TradingView Desktop │ <──────────────────────> │  Node.js MCP server  │
│  (Electron + Chrome) │   localhost:9222         │  (upstream package)  │
└──────────────────────┘                          └──────────┬───────────┘
                                                             │ stdio + JSON-RPC
                                                             ▼
                                                  ┌──────────────────────┐
                                                  │     Claude Code      │
                                                  │     (orchestrator)   │
                                                  └──────────────────────┘
```

Details in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Contributing

Bug reports, helper script improvements, doc fixes, and Windows edge-case troubleshooting are welcome. Upstream MCP server features and cross-platform abstractions are out of scope.

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

## License

MIT — see [`LICENSE`](LICENSE).

## Author

Aleksandr Gvozdkov — [LinkedIn](https://www.linkedin.com/in/YOUR_HANDLE)
