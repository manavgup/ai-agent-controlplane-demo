# Attendee agents in the quorum (chair-discovered, governed)

> Increment: let attendees register a REAL A2A voter agent into ContextForge; the chair already discovers `room-*` dynamically, so they join the quorum automatically. Re-adds the per-attendee registration that the hybrid pivot removed — but now chair-orchestrated and with the safeguards the Codex review wanted.

## Goal
Each attendee registers `room-<stance>-<initials>` (a real A2A agent in CF's `/a2a`, pointing at the shared room-agent backend via `?agent=`). Both quorum scenarios (`quorum` Companion-driven and `quorum_a2a` chair-orchestrated) discover `room-*` dynamically, so attendee agents vote in the governed quorum alongside the 5 fixed seeded voters. OPA still blocks the wire.

## Decisions (locked; vetoable)
- Attendee agent name = `room-<stance>-<initials>` so the existing `_stance_of()` (chair + companion) derives the stance from the name with NO downstream changes.
- Keep the 5 fixed seeded voters (baseline / empty-room safety).
- Keep local human Approve/Reject voting (additive); registration is a SEPARATE new control.
- Safeguards: room cap (`ATTENDEE_CAP=60`), dedup (numeric suffix), sanitized initials (A-Z0-9, ≤5), presenter freeze, and the chair/companion already treat a not-yet-materialized agent as abstain (try/except → abstain), so a fresh registration never crashes a quorum run.
- Chair fan-out becomes CONCURRENT (`asyncio.gather` + per-call timeout) and capped, to scale past 5.

## File Structure
**Modify:**
- `a2a-agents/chair/agent_executor.py` — concurrent voter fan-out (`asyncio.gather`, per-call 8s timeout, cap delegate count at 75); unchanged discovery/wire logic.
- `companion/app.py` — re-add `/api/register-agent` (POST initials+stance → register `room-<stance>-<initials>` in `/a2a`, cap+dedup+sanitize+freeze); helpers `_attendee_names()`, `_unique_room_name()`; a registration control in the dashboard `.roombar`; the wall/count shows registered agents. Keep local vote endpoints.
- `gateway/seed/seed.py` — unchanged (fixed 5 stay).
- `scripts/agents-reset.sh` — clear attendee `room-*` agents from `/a2a` (keep the fixed 5, or clear all + rely on `make seed` to re-add the 5). Use: clear all `room-*` then `make seed` re-adds fixed.
- `scripts/money-shots/quorum.sh` — add an assertion: after registering a temp attendee agent `room-strict-zz`, the chair's quorum includes it (voters count rises) and the wire still blocks; clean it up.

## Task H — chair concurrency + cap
In `a2a-agents/chair/agent_executor.py` `ChairAgent.run_quorum`, replace the sequential `for name in names:` voter loop with a concurrent fan-out:
- cap: `names = names[:75]` (defensive) after discovery.
- define an inner `async def _one(name)` that does the single voter POST (same body) with its own try/except → returns `(name, stance, vote)`, abstain on any error.
- `results = await asyncio.gather(*[_one(n) for n in names])` (gather never raises since each `_one` catches).
- keep the wire attempt + artifact formatting unchanged.
- add `import asyncio`.
Verify: `a2a-chair` still returns `QUORUM … wire_blocked=true voters=5` (fixed set), fast.

## Task I — attendee registration (Companion) + UI + reset + test
**Backend** (`companion/app.py`), near the crowd endpoints:
```
ATTENDEE_CAP = 60
REG_FROZEN = False  # presenter freeze for registration (separate from CROWD_FROZEN)

def _attendee_names():  # all room-* in /a2a that are NOT the fixed seeded set
    fixed = {"room-strict-1","room-strict-2","room-lenient-1","room-lenient-2","room-random-1"}
    return [n for n in _room_agent_names() if n not in fixed]

def _unique_room_name(stance, initials, existing):
    base = f"room-{stance}-{initials}"
    if base not in existing: return base
    i = 2
    while f"{base}-{i}" in existing: i += 1
    return f"{base}-{i}"
```
`/api/register-agent` (POST): sanitize initials; validate stance in STANCES (default random); if REG_FROZEN → 423; if `len(_attendee_names()) >= ATTENDEE_CAP` and new → 429; build `name=_unique_room_name(...)`, register into `/a2a` (endpoint `http://room-agent:8000/?agent=<name>`, agent_type jsonrpc, tags [finbyte,room,attendee]); dedup-retry on 409 like the old path; return `{ok,name,stance,count}`. Add `/api/agents` (count + recent attendee initials) and `/api/regfreeze` (presenter toggle, PRESENTER_KEY-guarded like /api/freeze).
**UI**: in `.roombar`, add a second control "🤖 Create your voting agent" with the initials input + a stance `<select>` (strict/lenient/random) + a "Register" button calling `/api/register-agent`; show the agent count. Wall can show agent count alongside votes (optional).
**Reset** (`scripts/agents-reset.sh`): delete all `room-*` from `/a2a` (the fixed 5 are re-added by `make seed`).
**Test** (`scripts/money-shots/quorum.sh`): register `room-strict-zz` via `/a2a`, wait ~3s, call `a2a-chair`, assert `voters=6` (5 fixed + 1) and `wire_blocked=true`, then delete `room-strict-zz`.

## Verify (whole increment)
- `a2a-chair` returns the quorum (now concurrent), wire blocked.
- Register an attendee agent via the Companion; run `quorum_a2a` → the agent appears in the tally; OPA blocks.
- `make verify-controls` green (quorum.sh now asserts attendee inclusion).
- Live screenshot: the quorum card showing fixed + attendee agents.
