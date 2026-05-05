# Troubleshooting

## Quick diagnostic flow

When something is wrong, run these three in order:

```powershell
.\scripts\verify-config.ps1     # Is the Claude Code config sane?
.\scripts\health-check.ps1      # Is TradingView's CDP reachable?
node --version                  # Is Node on PATH?
```

Most issues fall out of these three checks.

## Common errors

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | `tv_health_check` returns nothing or times out | TradingView launched without `--remote-debugging-port` | Quit TradingView and relaunch with `scripts\launch-tradingview-debug.ps1` |
| 2 | `CDP connection failed` / `ECONNREFUSED 127.0.0.1:9222` | Debug port not open, or wrong port in MCP server config | Run `health-check.ps1`. If port not listening, relaunch TradingView with the debug flag |
| 3 | `node: command not found` (or `'node' is not recognized`) | Node.js installed but not on PATH in the current shell | Close and reopen PowerShell. If still missing, reinstall Node.js with "Add to PATH" checked |
| 4 | MCP server not listed in Claude Code `/mcp` | Configured `.claude/.mcp.json` instead of `.claude.json` | Move the `mcpServers` entry into `~/.claude.json`. The leading dot and the location are both significant |
| 5 | `SyntaxError: Unexpected token` on Claude Code startup | Invalid JSON in `~/.claude.json` — typically single-backslash Windows paths or trailing comma | Double every backslash (`C:\\Users\\...`). Remove the trailing comma after the last entry. Run `verify-config.ps1` |
| 6 | MCP server starts but tools don't show up | `args[0]` points at a non-existent `server.js`, or to the package root instead of `src/server.js` | Check the path in `~/.claude.json` resolves to a real file. `verify-config.ps1` does this for you |
| 7 | `find-tradingview.ps1` returns "not found" | TradingView Desktop not installed, or installed via a non-Microsoft-Store installer (`.exe` installer) | Install from the Microsoft Store, or pass the executable path manually to `launch-tradingview-debug.ps1` |
| 8 | `Port 9222 already in use` | Another Chromium-based app is holding the port (often Chrome with `--remote-debugging-port`) | Use a different port: `launch-tradingview-debug.ps1 -Port 9223` and update the MCP server config to match |
| 9 | `tv_screenshot` returns a blank or solid-color image | TradingView window is minimized or hidden behind other windows | Restore the TradingView window. CDP screenshots reflect actual rendered output |
| 10 | Claude Code freezes for ~30s on startup | MCP server retrying CDP connection because TradingView isn't running | Launch TradingView with the debug flag *before* starting Claude Code |

## Still stuck?

Open an issue: [github.com/voronezh00136-bit/tradingview-mcp-windows-guide/issues](https://github.com/voronezh00136-bit/tradingview-mcp-windows-guide/issues)

Include in the report:

- **Output of `verify-config.ps1`** (redact your username if you prefer)
- **Output of `health-check.ps1`**
- **Windows version** — `winver` or `[System.Environment]::OSVersion`
- **Node.js version** — `node --version`
- **Claude Code version** — from the app
- **TradingView Desktop version** — Help → About inside the app
- **The exact error message** as shown in Claude Code or the terminal
- **What you've already tried** from the table above
