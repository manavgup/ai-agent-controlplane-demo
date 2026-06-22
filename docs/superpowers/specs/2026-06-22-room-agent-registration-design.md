# Room agent registration + live count — design

**Date:** 2026-06-22
**Status:** approved, building
**Branch:** dev-day-non-coder-followalong (PR #21)

## Goal

Turn the "build an agent with Bob" beat into audience participation: each attendee
names an agent with their initials and **registers it with ContextForge**, and the
room watches the **agent count climb live** on their phones and on a projected wall.

## Decisions (from brainstorming)

- **Who:** everyone. Tier-1 phones register via the Companion (no install); Tier-2/3
  drivers register via Bob.
- **What registers:** a **real** `register_mcp_server` call → a genuine catalog entry
  `salestax-<INITIALS>`, all pointing at the one shared `sales-tax` backend. The count
  is real ContextForge servers growing.
- **Dedup + retry:** force-unique names (`salestax-MG`, `salestax-MG-2`, …); retry the
  gateway call on collision/error.
- **Counter:** both a phone counter (Companion) and a projected `/wall` view. Dark IBM theme.
- **Surface:** Companion-only for the audience (Tier-1 destination). `follow.html` unchanged.

## Components

### Companion (`companion/app.py`) — new endpoints
- `POST|GET /api/register-agent?initials=XX`
  - Sanitize: uppercase, keep `[A-Z0-9]`, 1–5 chars; empty → `ANON`.
  - Compute unique name: `salestax-<INI>`, else `-2`, `-3`… (scan existing `salestax-*`).
  - Register via the **controlplane register tool** over the existing `/rpc` path
    (same call Bob's operator makes), url = `AGENT_BACKEND_URL`
    (default `http://sales-tax:8000/mcp`). **Retry** on name collision / error, up to 10,
    advancing the suffix each try.
  - Returns `{ ok, name, initials, count }`.
- `GET /api/agents`
  - List `/servers`, filter `salestax-*`. Returns `{ count, recent: [name…] }` (newest first).
- `GET /wall`
  - Full-screen dark view: giant `count`, initials scrolling in, polls `/api/agents` ~2s.

### Companion UI (dashboard)
- A "🛠️ Build & register your agent" card at the top: initials `<input>` + "Register my
  agent ▶" button → `POST /api/register-agent` → shows `✓ Registered salestax-MG-3`.
- A prominent **"Agents built by the room: N ↑"** counter, polling `/api/agents` ~3s.

### Bob lane (docs/prompts)
- `build.html` Stage ② register prompt → name with initials:
  *"Register the sales-tax service … under the name `salestax-<YOUR-INITIALS>`."*
- `dev-day-runsheet.md` — same, plus a line about the phone register + `/wall`.

### Reset (`Makefile`)
- `make agents-reset` — remove all `salestax-*` servers from the catalog. Folded into
  `make demo-reset` so each session starts at 0.

## Data flow

```
phone → POST /api/register-agent?initials=MG
  companion: sanitize → dedup name → rpc(controlplane-register-mcp-server,{name,url}) [retry]
  → returns {name:"salestax-MG", count:N}
phone/wall ← GET /api/agents (poll) → {count:N, recent:[...]}  → counter climbs
```

## Edge cases
- Empty/garbage initials → `ANON`. Over 5 chars → truncated.
- Name collision / gateway race → retry with next suffix (bounded).
- `sales-tax` backend down → entry still registers (count climbs); `AGENT_BACKEND_URL`
  configurable so we can point at an up backend for testing on the live Codespace.
- Flooding (public endpoint): acceptable for a throwaway demo; `agents-reset` cleans up.

## Testing
- On the live Codespace: fire several `/api/register-agent` calls with different initials
  (a few subagents), confirm `/api/agents` count climbs, screenshot the phone counter and
  `/wall`. Confirm `make agents-reset` returns to 0.

## Out of scope
- Per-attendee real containers (impossible at room scale). Persisting names across resets.
  follow.html changes. Auth/rate-limiting beyond name dedup.
