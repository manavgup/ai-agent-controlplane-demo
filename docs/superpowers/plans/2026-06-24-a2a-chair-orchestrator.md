# A2A Chair Orchestrator — agent-orchestrated governed quorum

> Increment on top of the hybrid quorum (PR #24). Adds a real A2A **host agent** that orchestrates the quorum, so the demo shows genuine agent→agent delegation (discover → delegate → aggregate → act), not just app-driven fan-out. Keeps the Companion-driven `quorum` scenario as the robust fallback; this lands as a SECOND scenario `quorum_a2a`.

**Goal:** A new `chair` A2A agent that, when invoked, discovers the room voter agents from ContextForge's `/a2a` registry, delegates a vote to each **through the gateway** (governed + audited), tallies, attempts the $50k wire (OPA blocks), and returns the result as an A2A artifact. The Companion's new `quorum_a2a` scenario kicks the chair off with a single A2A message and renders the chain.

**The chain:** `Companion → [A2A] → Chair agent → discovers voters (/a2a) → [A2A via gateway] → 5 voter agents → tally → wire → OPA DENY → [A2A artifact] → Companion`.

**Why this is the same risk profile as the auditor:** the chair is structurally identical to `a2a-agents/auditor/` — a Python `a2a-sdk` agent that receives a task and itself calls the gateway `/rpc` over HTTP. The auditor already does exactly this (calls `a2a-payments`). The chair just does it in a loop after a `/a2a` discovery GET. Deterministic, no LLM.

## Decisions (locked)
- Chair reaches voters **through the gateway** (`/rpc`), not peer-to-peer → every vote authn'd + audited (governed-mesh thesis).
- Chair is a **real registered A2A agent** (own card, in `/a2a`, invokable as tool `a2a-chair`).
- Deterministic chair (no LLM) → stage-robust.
- Existing `quorum` scenario stays; this is additive (`quorum_a2a`).
- Chair reuses the auditor's token plumbing: `GATEWAY_TOKEN=${AUDITOR_TOKEN}` (already an admin token written by `make up`), so no Makefile change.

## Artifact contract (chair → Companion)
The chair returns artifact text the Companion greps out of the (nested, escaped) A2A response with simple regexes that survive JSON escaping — same approach as `_vote_one`'s `VOTE=` grep. Format:
```
QUORUM agent_approve=<n> agent_reject=<n> agent_abstain=<n> wire_blocked=<true|false> voters=<n>
room-strict-1=reject room-strict-2=reject room-lenient-1=approve room-lenient-2=approve room-random-1=reject
wire_detail: <short OPA reason or result>
```

## File Structure
**Create:**
- `a2a-agents/chair/__main__.py` — card "Approval Chair Agent" (skill `run_quorum`), card routes + JSON-RPC `/` + `/health`, on `0.0.0.0:8000`.
- `a2a-agents/chair/agent_executor.py` — `ChairAgentExecutor`: parse amount/payee → discover voters → fan out votes via gateway → tally → wire → format artifact.
- `a2a-agents/chair/Dockerfile` — FROM python:3.12-slim, `pip install "a2a-sdk[http-server]==1.1.0" uvicorn httpx` (needs httpx for gateway calls, like the auditor).

**Modify:**
- `docker-compose.yml` — add `chair` service (build ./a2a-agents/chair, env GATEWAY_URL + GATEWAY_TOKEN=${AUDITOR_TOKEN:-}, depends_on gateway, ports 9200:8000, restart unless-stopped).
- `gateway/seed/seed.py` — add `"chair": "http://chair:8000/"` to the `A2A` dict so it registers + becomes tool `a2a-chair`.
- `companion/app.py` — add `s_quorum_a2a()` + `SCENARIOS["quorum_a2a"]`; add the card to the dashboard `SCEN` array.
- `scripts/money-shots/quorum.sh` — add 1 assertion: calling `a2a-chair` returns a `QUORUM … wire_blocked=true` artifact (agent-orchestrated path blocks too).
- `docs/evidence/a2a-quorum/` — add a screenshot of the agent-orchestrated card + a chain note.

## Task A — chair agent + seed + compose
Mirror `a2a-agents/auditor/`. Executor (async, httpx) — pseudocode locked in the implementer prompt:
- `discover()`: `GET {GATEWAY_URL}/a2a` with bearer token → names starting `room-`.
- `_stance_of(name)`: strict/lenient/random substring.
- per voter: `POST {GATEWAY_URL}/rpc` tool `a2a-<name>` with `{"message":{"role":"ROLE_USER","parts":[{"text":"… stance=<s> agent=<name>"}],"messageId":"chair-<name>"}}`, 8s timeout; grep `json.dumps(resp)` for `VOTE=approve|reject` else abstain.
- wire: `POST /rpc` `erp-payments-wire {payee, amount, approval:false}`; `blocked = "Plugin Violation" in dumps`; extract `Wire amount …` reason.
- Emit Working → artifact(text per contract) → Completed.
- Robust: any HTTP error per voter → abstain; never raise out of the executor.

Verify: build; `make seed` registers `chair`; `curl /rpc a2a-chair "Run the approval quorum for a $50000 wire to Acme LLC"` → artifact contains `QUORUM … wire_blocked=true` and 5 `room-*=` votes.

## Task B — Companion `quorum_a2a` scenario + card
`s_quorum_a2a()`:
- crowd tally (local, as in `s_quorum`).
- `rpc("a2a-chair", {"message":{...,"parts":[{"text":"Run the approval quorum for a $50000 wire to Acme LLC"}], "messageId":"companion-chair"}}, timeout=30)`.
- grep the artifact: `agent_approve=(\d+)`, `agent_reject`, `agent_abstain`, `wire_blocked=true`, per-agent `(room-[\w-]+)=(approve|reject|abstain)` (dedup first occurrence), `wire_detail: ([^"\\]+)`.
- `verdict="BLOCKED" if wire_blocked else "SEE RAW"`; headline emphasizes the chain ("Chair agent discovered N voters, delegated via the gateway, OPA blocked the wire").
- detail: show the chain, crowd tally, the agent votes, the blocked wire. If the chair is unreachable (no markers found), degrade to a clear "chair agent unreachable" message (verdict "SEE RAW").
- `SCENARIOS["quorum_a2a"] = ("Agent-orchestrated quorum — a chair agent runs it (A2A)", s_quorum_a2a)`.
- Dashboard `SCEN`: append `["quorum_a2a","Agent-orchestrated quorum — chair agent (A2A)"]`.

Verify: `curl /api/run/quorum_a2a` → BLOCKED with the chain + agent votes; dashboard card runs; both `quorum` and `quorum_a2a` work.

## Verification (whole increment)
- `make verify-controls` → still green (now +1 quorum assertion = 20 passed).
- Live: run both quorum cards; screenshot the agent-orchestrated one; confirm `make inspect-a2a` lists the `chair` + voter cards (raw-protocol beat).
