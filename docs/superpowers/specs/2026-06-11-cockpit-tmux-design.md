# `make cockpit` — tmux multi-window control-plane cockpit

**Date:** 2026-06-11
**Status:** Design approved, pending spec review
**Author:** brainstormed with Claude

## Problem

Advanced users and presenters want to watch *everything* at once — drive Bob while seeing the gateway logs, OPA policy decisions, the MCP Inspector, and the A2A Inspector live. Today this requires opening each surface by hand in separate terminals/tabs (the TALK-PREP guide literally instructs the presenter to do so). There is no single command that lays them all out together. `make companion` gives a single read-only browser dashboard, but not the multi-pane "cockpit" view.

## Goal

A `make cockpit` target that spawns a tmux session tiling the interactive Bob session alongside the live watch surfaces, so an advanced user gets the whole control plane in one window with one command. Must work on macOS and Linux, including over SSH — the demo's standing constraint is that it runs everywhere, not just the author's Mac.

## Non-goals

- Resizing the OS terminal window to fullscreen (not portable; the user maximizes their terminal).
- A new GUI. This is terminal-native (tmux) plus the browser UIs the inspectors/monitor already open.
- Replacing `make companion` or the individual targets — the cockpit composes them.
- Windows support (the demo targets macOS/Linux; tmux on Windows would be via WSL, out of scope).

## Approach

A thin `cockpit` Makefile target delegates to `scripts/cockpit.sh`. Each tmux pane runs an existing `make <target>`, so the cockpit is **pure orchestration and reuses all current logic** — no duplicated token-minting, UUID lookups, or log commands.

### Mechanism: tmux (chosen)

tmux gives identical behavior on macOS/Linux, works over SSH/headless, and needs no per-terminal-emulator detection. Trade-off: it's a dependency. If tmux is absent the script prints an install hint and falls back to listing the individual targets (never an ugly crash). Native OS-window spawning (osascript/gnome-terminal/…) and browser-tabs-only were considered and rejected — the former is fragile and SSH-hostile, the latter gives Bob no home and collapses the logs into one pane.

### Layout

One tmux session named `cockpit`, one window:

```
┌───────────────────────┬───────────────┐
│                       │ make logs     │  gateway log tail
│  make bob             ├───────────────┤
│  (interactive,        │ make logs-opa │  OPA ALLOW/DENY decisions
│   big left pane,      ├───────────────┤
│   ~62% width)         │ make inspect-mcp │ npx inspector (opens browser)
│                       ├───────────────┤
│                       │ make inspect-a2a │ docker run, serves :8090
└───────────────────────┴───────────────┘
```

- Pane sizes are set explicitly (Bob ~62% width; the right column split into four roughly-equal stacked panes), not left to tmux's even-split default.
- `make monitor` (ContextForge Admin UI) is a one-shot URL open, not a long-running process, so the script fires it once at startup as a browser tab — no dedicated pane.
- Bob defaults to the **analyst** persona (`make bob`). `COCKPIT_PERSONA=operator make cockpit` swaps the Bob pane to `make bob-operator`.

### Preflight guards (in `scripts/cockpit.sh`, before building the session)

1. **tmux missing** → print install hint (`brew install tmux` / `sudo apt-get install tmux`), then list the individual targets (`make bob`, `make logs`, `make logs-opa`, `make inspect-mcp`, `make inspect-a2a`, `make monitor`) as the manual fallback. Exit 0.
2. **gateway not healthy** (`curl -sf localhost:4444/health` fails) → print "Stack isn't up — run `make quickstart` first." Exit 1.
3. **terminal too small** (`tput cols` < 120 or `tput lines` < 32) → warn "maximize your terminal — 5 panes need room" and continue (warning only, not fatal).

### `$TMUX`-aware behavior (answers "can I run it from within Bob?")

- **Not already in tmux** → create the full `cockpit` session (Bob in the big pane + the four watch panes), then attach. This is the normal entry point: cockpit hosts Bob; you do **not** pre-start Bob.
- **Already in tmux** (e.g. the user launched `make bob` inside a tmux pane and runs `make cockpit` from a Bob shell-escape or a sibling pane) → do **not** spawn a second Bob. Instead split the *current* window to add the four watch panes around the existing pane.

Hard limit, documented: a Bob (or any process) already running in a **plain, non-tmux** terminal cannot be retrofitted into tmux — tmux cannot adopt an existing external process. In that case (no `$TMUX`, and the watch-only augment isn't applicable) the cockpit simply launches its own Bob. The supported way to "run cockpit from within Bob" is therefore to start Bob inside tmux.

### Teardown

The session is named `cockpit`. `Ctrl-b &` (tmux's kill-window) or `make cockpit-down` (→ `tmux kill-session -t cockpit`) tears down every pane at once. Because `make inspect-a2a` uses `docker run --rm` and `make logs`/`logs-opa` are foreground tails, killing the panes stops the inspector process, removes the A2A container, and ends the tails — no orphaned processes.

## Components

| Unit | Responsibility | Depends on |
|---|---|---|
| `scripts/cockpit.sh` (new) | Preflight checks; build/augment the tmux session; open the monitor tab; attach | tmux, the existing `make` targets, `curl`, `tput` |
| `cockpit` target (Makefile) | One-line entry: `@bash scripts/cockpit.sh` | the script |
| `cockpit-down` target (Makefile) | `tmux kill-session -t cockpit 2>/dev/null || true` | tmux |
| README/RUNBOOK note | "Advanced: watch everything with `make cockpit`" | — |

## Cross-platform notes

- tmux commands are identical on macOS/Linux. The only OS-specific bit is the browser open, which reuses the existing `open || xdg-open` pattern already in `make monitor`.
- Works over SSH (tmux); native-window approaches would not.

## Testing / verification

Manual (this is interactive tooling — no unit test harness fits cleanly):
1. **Cold start, no tmux installed** → install hint + fallback list, exit 0.
2. **Cold start, stack down** → "run `make quickstart` first", exit 1.
3. **Cold start, stack up** → cockpit session builds, Bob in big pane, four watch panes populate, Admin UI tab opens.
4. **Small terminal** → warning prints, session still builds.
5. **Already in tmux** → watch panes added around the current pane; no second Bob.
6. **`make cockpit-down`** → session gone, `docker ps` shows the a2a-inspector container removed, no orphaned `npx`/log processes.
7. **`COCKPIT_PERSONA=operator`** → Bob pane runs the operator persona.

The change is additive (new script + two targets + a doc note); it touches no existing target, so the CI gate (`make check`) is unaffected.
