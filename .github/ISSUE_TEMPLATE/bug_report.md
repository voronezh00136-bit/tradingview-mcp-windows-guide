---
name: Bug report
about: Something on Windows isn't working as documented
title: "[BUG] "
labels: bug
assignees: ''
---

## What happened

A clear, factual description of the bug. Quote the exact error message if there is one.

## What you expected

What did you expect to happen instead?

## Steps to reproduce

1.
2.
3.

## Output of diagnostic scripts

Paste the output of these two scripts. Redact your username if you prefer.

```
PS> .\scripts\verify-config.ps1
(paste output here)
```

```
PS> .\scripts\health-check.ps1
(paste output here)
```

## Environment

- **Windows version:** (run `winver`, e.g. "Windows 11 23H2")
- **PowerShell version:** (run `$PSVersionTable.PSVersion`)
- **Node.js version:** (run `node --version`)
- **Claude Code version:** (from the app's About / version info)
- **TradingView Desktop version:** (Help → About inside TradingView)
- **Upstream tradingview-mcp commit:** (run `git -C "$env:USERPROFILE\.claude\tools\tradingview-mcp" rev-parse --short HEAD`)

## What you've already tried

Reference the troubleshooting table in [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md). Which entries did you try? What changed?

## Additional context

Anything else relevant — non-default Node install path, antivirus interference, group policy restrictions on WindowsApps, etc.
