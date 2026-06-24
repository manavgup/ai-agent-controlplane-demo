# A2A Quorum — "Policy Beats Consensus"

**Date:** 2026-06-24
**Status:** Approved design, pending implementation plan
**Branch:** `dev-day-non-coder-followalong`

## Problem

The demo already runs two real A2A agents (`auditor` in Python, `payments` in
Rust), serves agent cards at `/.well-known/agent-card.json`, and governs every
A2A call through the ContextForge gateway (`:4444`) + OPA. What it lacks is an
**agent-to-agent collaboration moment that attendees participate in**, and a
story for **A2A discovery**.

The public `a2a-registry.org` was considered for discovery but rejected: it is a
third party we do not control or trust for a live demo. The reframe is stronger:

> **ContextForge *is* the registry.** It already has an A2A catalog (`/a2a`),
> already serves agent cards, and already governs every A2A call. Attendees
> create real A2A agents that land in *our* governed registry, and collaboration
> happens through the control plane — not a random third party.

## Goal

Attendees scan the QR, name an agent, and pick a voting **stance**. Their agents
become real, governed A2A citizens in the gateway catalog. A quorum scenario
fans an expense out to every room agent; votes stream onto the dashboard live;
the room reaches a verdict. Then the punchline: a $12k wire is attempted and
**OPA blocks it regardless of the vote**.

**The line: _Policy beats consensus._**

## Non-Goals

- No dependency on `a2a-registry.org` or any external registry.
- No LLM in the voting hot path (stage reliability + latency).
- No replacement of the existing `sales-tax` MCP beat — that stays untouched.
- No per-attendee OS process; one shared backend serves many logical agents.

## On-Stage Narrative (the beats)

1. "ContextForge is your A2A registry — you don't need to trust a public one."
2. Attendees scan the QR, name their agent, pick a stance → real A2A agents
   appear in the governed catalog, the live count climbing.
3. Fire the quorum: an expense fans out to every room agent; votes stream in
   live; the room reaches a verdict.
4. **Punchline:** attempt the $12k wire → OPA **BLOCKS** it even with unanimous
   approval. Then show the audit trail — every vote was authn'd and logged by
   the gateway.

## Architecture

### Runtime topology (additions in **bold**)

```
Companion (:7070, Flask) ──orchestrates──┐
                                         ▼
                          Gateway / ContextForge (:4444)
                          ├─ plugin chain (FinByteGuard, PIIFilter)
                          ├─ OPA (:8181) — wire ≥ $10k → DENY
                          ├─ A2A catalog (/a2a)
                          │    ├─ auditor   (:9001)   [existing]
                          │    ├─ payments  (:3000)   [existing]
                          │    └─ room-<name> ...      [NEW, registered live]
                          └─ MCP servers (expense-db, erp-payments, …) [existing]

**room-agent (:8000, Python a2a-sdk)** — one process, many logical agents
   ├─ /.well-known/agent-card.json   (named per attendee)
   ├─ JSON-RPC endpoint              (vote_expense skill)
   └─ /register                      (name + stance → in-memory map)
```

### Components

#### 1. Room-agent backend — NEW (`a2a-agents/room/`)

Shared A2A service in Python using `a2a-sdk`, mirroring the structure of
`a2a-agents/auditor/` (`__main__.py`, `agent_executor.py`).

- **Agent card** at `/.well-known/agent-card.json`, named per attendee. The
  gateway registers each room agent with an endpoint URL carrying the name
  (the `sales-tax` `?agent=` trick), e.g.
  `http://room-agent:8000/?agent=room-<name>`.
- **Skill** `vote_expense(expense) → {vote, reason}` where `expense` carries
  `payee`, `amount`, `approval`.
- **Stance** is stored in an in-memory map keyed by agent name, populated when
  the Companion POSTs to `/register`. Three stances:
  - **Strict** — reject if `amount >= STRICT_THRESHOLD` (default $5,000) or
    `approval` is missing/false.
  - **Lenient** — approve unless `approval` is explicitly `false`.
  - **Random** — deterministic pseudo-random from a hash of `name + amount`
    (reproducible on stage; no `random`/wall-clock entropy).
- The executor reads the agent name from the request path/query, looks up the
  stance, computes the vote, returns a structured result.

**Empty-room safety:** seed **2 demo room agents** at startup (e.g.
`room-demo-strict`, `room-demo-lenient`) so the quorum always works even if no
attendee has scanned yet.

#### 2. Companion changes (`companion/app.py` + templates)

- **Join form** gains a **stance dropdown** (Strict / Lenient / Random) next to
  the name field.
- **`/api/register-agent`** (extends existing):
  1. POST `name + stance` to the room backend `/register`.
  2. Register `room-<name>` into the gateway **A2A catalog** via `POST /a2a`
     (not `POST /gateways`).
  - Duplicate names get a numeric suffix (`room-mg`, `room-mg-2`).
  - The live agent count / wall now reads "A2A agents in the registry."
- **`/api/run/quorum`** — NEW scenario:
  1. `GET` gateway `/a2a`, filter `room-*`.
  2. For each, invoke the agent **through** the gateway `/rpc` (so every call is
     authn'd + audited) with the expense message.
  3. Tally votes; per-vote timeout → **abstain** (never crash the tally).
  4. Attempt the **$12k wire** via the existing payments/erp path with no
     approval → OPA **BLOCKS**.
  5. Return a structured result (votes + tally + final verdict) for the
     dashboard.
- **Dashboard** gains a **quorum panel**: votes land one-by-one, then the OPA
  verdict banner ("BLOCKED by control-plane policy — policy beats consensus").

#### 3. Infra (`docker-compose.yml`)

- Add the `room-agent` service (internal `:8000`), same network as the other
  A2A agents.
- No new OPA rule required for the core: votes are not `wire|payment`, so they
  pass **and are audited**; the existing `wire|payment` Rego rule blocks the
  finale.

#### 4. Tests (`make verify-controls`)

Extend the pytest suite:
- Register 2–3 room agents across different stances.
- Run the quorum; assert a **mixed tally** (stances produce different votes).
- Assert the **$12k wire is BLOCKED** regardless of the tally.
- Assert a downed/timing-out room agent is counted as **abstain**, not an error.

## Data Flow (quorum scenario)

```
Companion /api/run/quorum
  │
  ├─ GET gateway:4444/a2a               → [room-strict, room-lenient, …]
  │
  ├─ for each room agent (concurrent, per-call timeout):
  │     POST gateway:4444/rpc  tool=a2a-room-<name>
  │       → gateway plugin chain + audit log
  │       → room-agent vote_expense (stance lookup) → {vote, reason}
  │     (timeout → abstain)
  │
  ├─ tally votes → stream to dashboard panel
  │
  └─ POST gateway:4444/rpc  wire($12,000, approval=false)
        → OPA: amount ≥ $10k AND approval≠true → DENY
        → dashboard: BLOCKED banner ("policy beats consensus")
```

## Error Handling

- **Empty room:** 2 seeded demo agents guarantee a non-empty quorum.
- **Room agent down / slow:** per-vote timeout → counted as abstain; tally and
  finale still complete.
- **Duplicate attendee name:** numeric suffix on registration.
- **Gateway registration failure:** fast-fail with a clear error surfaced to the
  attendee's join page (consistent with existing register-agent behavior).

## Testing Strategy

- Unit: stance logic (`vote_expense`) for Strict / Lenient / Random across
  boundary amounts and missing-approval cases; Random is deterministic.
- Integration (`make verify-controls`): full quorum run with mixed stances +
  blocked finale + abstain-on-timeout.
- Manual stage check: `make companion-connect` / `make present`, scan from a
  phone, register an agent, run the quorum, observe the live tally + block.

## Optional Stretch (out of scope unless requested)

An OPA rule that stamps the **calling agent** (`input.source_agent`) on every
vote call, producing a richer per-agent audit trail. Core ships without it:
votes are already audited and the finale already blocks.

## Open Questions

None blocking. Threshold values (Strict $5k, wire $10k/$12k) are demo knobs and
can be tuned during implementation.
