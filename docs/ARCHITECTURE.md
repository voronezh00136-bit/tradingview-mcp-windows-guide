# Architecture

## High level

```
┌──────────────────────┐                          ┌──────────────────────┐
│  TradingView Desktop │                          │     Claude Code      │
│  ┌────────────────┐  │                          │                      │
│  │ Electron shell │  │                          │   user types prompt  │
│  │ + Chromium     │  │                          │   that needs chart   │
│  └────────────────┘  │                          │   data               │
│         ▲            │                          └──────────┬───────────┘
│         │ DevTools   │                                     │
│         │ Protocol   │                                     │ stdio
│         │            │                                     │ JSON-RPC
│         ▼            │   WebSocket on                      ▼
│   localhost:9222 <───┼───localhost:9222 <──┐    ┌──────────────────────┐
│                      │                     └────│  Node.js MCP server  │
└──────────────────────┘                          │  (upstream package)  │
                                                  └──────────────────────┘
```

## Components

### TradingView Desktop

An Electron application with an embedded Chromium runtime. When launched with `--remote-debugging-port=9222`, it exposes the Chrome DevTools Protocol on `127.0.0.1:9222`. CDP is the same protocol Puppeteer and Playwright use to drive Chrome — it lets an external process inspect the DOM, evaluate JavaScript, dispatch input events, and capture screenshots.

The `--remote-debugging-port` flag is a standard Chromium switch. It is not a TradingView feature, which is why it works without any special TradingView API.

### Node.js MCP server

The upstream [tradesdontlie/tradingview-mcp](https://github.com/tradesdontlie/tradingview-mcp) project. It is an MCP server that:

1. Connects to CDP at `127.0.0.1:9222` over WebSocket.
2. Exposes a set of MCP tools (e.g. `tv_health_check`, `tv_screenshot`) that translate to CDP commands like `Page.captureScreenshot` and `Runtime.evaluate`.
3. Speaks the MCP protocol over stdio to its parent process.

It runs as a child of Claude Code, not as a standalone daemon.

### Claude Code

The MCP host. On startup it reads `~/.claude.json`, finds the `mcpServers` block, and spawns each configured server as a subprocess. It communicates with each server over the subprocess's stdin/stdout using JSON-RPC framed by the MCP transport spec.

When Claude needs to call a tool, it sends a `tools/call` request down stdin. The server runs the corresponding CDP command, formats the result, and writes the response to stdout.

## Chrome DevTools Protocol

CDP is a JSON-over-WebSocket protocol. Domains relevant here:

- `Page` — navigation, screenshots, reload
- `Runtime` — evaluate JavaScript expressions in the page context
- `Input` — synthesize mouse and keyboard events
- `DOM` — query and mutate the DOM tree

Reference: [chromedevtools.github.io/devtools-protocol](https://chromedevtools.github.io/devtools-protocol/).

## MCP transport

MCP supports several transports. This setup uses `stdio`:

- **Framing:** newline-delimited JSON-RPC 2.0 over the subprocess's stdin/stdout.
- **Lifetime:** server is spawned by the host on startup and killed on shutdown. There is no separate listening port for MCP itself.
- **Discovery:** the host calls `tools/list` after the handshake to learn which tools the server exposes.

## Lifecycle

**Claude Code starts:**

1. Reads `~/.claude.json`.
2. For each `mcpServers` entry, spawns the configured `command` with `args`.
3. Performs the MCP handshake on stdio.
4. Calls `tools/list`. The MCP server, in parallel, opens a WebSocket to `ws://127.0.0.1:9222/devtools/browser/...`.

**Tool call:**

1. User prompt triggers the model to emit a `tools/call` for, say, `tv_screenshot`.
2. Claude Code writes the JSON-RPC request to the MCP server's stdin.
3. The server sends `Page.captureScreenshot` over CDP.
4. TradingView returns base64 PNG.
5. Server wraps it in a `tools/call` response and writes to stdout.
6. Claude Code returns it to the model.

**Shutdown:**

1. User exits Claude Code.
2. Claude Code closes the subprocess's stdin.
3. The MCP server closes its CDP WebSocket and exits.
4. TradingView keeps running — it has no awareness that a CDP client disconnected.

## Extending it

To add a new tool, fork the upstream MCP server and add a handler. The pattern looks like:

```javascript
// Pseudocode — see upstream src/server.js for the real interface
server.tool('tv_click_at', async ({ x, y }) => {
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mousePressed', x, y, button: 'left', clickCount: 1
  });
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mouseReleased', x, y, button: 'left', clickCount: 1
  });
  return { ok: true };
});
```

Useful CDP commands for TradingView automation:

- `Runtime.evaluate` — run arbitrary JS against the TradingView page (read state from `window.TradingView` or DOM)
- `Input.dispatchMouseEvent` — click, drag, hover
- `Input.dispatchKeyEvent` — keyboard input (e.g. typing a symbol into the search box)
- `Page.captureScreenshot` — screenshot, optionally clipped to a rect
- `DOM.querySelector` + `DOM.getBoxModel` — find UI elements and their on-screen coordinates

## Security notes

The CDP endpoint at `localhost:9222` is **unauthenticated**. Any process on the local machine that can open a TCP connection to that port can drive TradingView — read your watchlists, your open charts, click around, capture screenshots.

This is normal for Chromium's `--remote-debugging-port` and is why Chromium binds it to `127.0.0.1` only.

Do not:

- Forward port 9222 to a public interface
- Bind it to `0.0.0.0` via `--remote-debugging-address`
- Expose it through SSH tunnels or `ngrok` to untrusted networks
- Run untrusted Node.js modules in the same user session — they can connect to CDP

If you want isolation, run TradingView and Claude Code under a dedicated Windows user account.
