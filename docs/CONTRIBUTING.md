# Contributing

Thanks for considering a contribution. This repo is small and focused, so the scope rules below matter more than usual.

## What's in scope

- Bug reports for Windows-specific failure modes
- New helper scripts that automate Windows setup or diagnosis
- Documentation fixes, clarifications, missing edge cases
- Translations of `SETUP.md` and `TROUBLESHOOTING.md`
- Additions to the troubleshooting table — symptom + cause + fix, ideally with the exact error string

## What's out of scope

- Features for the upstream MCP server itself — open those at [tradesdontlie/tradingview-mcp](https://github.com/tradesdontlie/tradingview-mcp)
- Cross-platform abstractions. macOS and Linux setups are different enough that a unified guide would lose detail. A separate `tradingview-mcp-macos-guide` would be welcome, just not here.
- Generic Claude Code or MCP tutorials — link to upstream docs instead

## Workflow

1. **Open an issue first** for non-trivial changes. Two reasons: it lets us discuss scope before you write code, and it gives the change a stable URL for the changelog.
2. **Fork** the repository, **branch** from `main`, **commit** with a clear message.
3. **Test on a real Windows machine.** PowerShell scripts written and tested only in WSL or on macOS will be rejected — too many subtle differences (`Get-AppxPackage`, MSIX paths, `Get-NetTCPConnection` behavior, console color rendering).
4. **Open a PR** against `main` with a description of the problem, the fix, and the platform you tested on (Windows version, PowerShell version).

## Style guide

### Markdown

- Sentence-case headings, not Title Case
- Fenced code blocks always have a language tag (```powershell, ```json, ```javascript)
- Tables for any list of options, errors, or comparisons
- Inline code (`backticks`) for filenames, paths, commands, and variable names
- Prefer prose for "why" explanations; use lists only for genuinely enumerable items

### PowerShell

Every script starts with a comment-based help block:

```powershell
<#
.SYNOPSIS
    One-line summary.

.DESCRIPTION
    Two to four sentences explaining what the script does and why it exists.

.PARAMETER Name
    Describe each parameter.

.EXAMPLE
    PS> .\my-script.ps1
    Sample output line 1
    Sample output line 2

.NOTES
    Author: Aleksandr Gvozdkov
    Requires: PowerShell 5.1+ or PowerShell 7
#>
```

Followed by:

```powershell
[CmdletBinding()]
param(
    [int]$Port = 9222
)

$ErrorActionPreference = "Stop"
```

Color conventions:

- `Write-Host "[OK]   ..." -ForegroundColor Green` — success
- `Write-Host "[WARN] ..." -ForegroundColor Yellow` — warning, recoverable
- `Write-Host "[ERR]  ..." -ForegroundColor Red` — failure
- `Write-Host "[INFO] ..." -ForegroundColor Cyan` — informational headers and progress

Exit non-zero on failure when the script is meant to be used in a pipeline.

## License

By contributing you agree your changes are licensed under the same MIT license as the rest of the repository.
