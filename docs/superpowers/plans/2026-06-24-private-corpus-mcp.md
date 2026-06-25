# Private corpus over MCP — full stack (MCP feeds A2A, governed)

> Each attendee provides a private note at Join. A `corpus` MCP server serves it; each voter agent reads its owner's note over MCP (governed: PII redacted, injection neutralized, audited) and votes per the note's rule. OPA still blocks the wire. Plus: the wall shows the discovered A2A agents + stance.

## The chain
```
Attendee Join (initials + stance + note) → Companion stores note → corpus MCP server
Quorum: chair → [A2A] → voter → reads owner's note via [MCP through gateway, GOVERNED] → votes per note → tally → wire → OPA DENY
```

## Decisions (locked)
- **Shared `corpus` MCP server** (one, seeded), tool `get_corpus(owner)` returning the note. Simpler + robust than per-attendee corpus servers. The attendee still registers `salestax-<initials>` (catalog beat) — corpus is the governed data plane the voters read.
- **Companion writes** notes to the corpus server at Join (`POST /set`, host→published port); the **gateway reads** them (`/mcp`, mesh). Avoids a corpus→Companion callback across the host boundary.
- **Note → vote** (pure, deterministic): dollar figure in note = approval cap (reject if amount ≥ cap); else "approve"/"reject" keyword honored; else fall back to stance. Missing/unreadable note → stance. Never crashes.
- **Governance** is automatic: the gateway's PII filter + injection filter + audit apply to the corpus read (same plugins that mask `get_receipt`). The voter sees the GOVERNED note.
- Voter (`room-agent`) gains gateway access (GATEWAY_URL + GATEWAY_TOKEN=${AUDITOR_TOKEN}) to read the corpus tool. Fixed voters (owner `1`/`2`) have no note → stance, unchanged.

## File Structure
**Create:**
- `mcp-servers/corpus/server.py` — FastMCP: in-memory `{owner: note}`; tool `get_corpus(owner)`; custom routes `POST /set` (Companion writes) + `GET /health`.
- `mcp-servers/corpus/Dockerfile` — mirrors `mcp-servers/sales-tax/` (FastMCP).

**Modify:**
- `docker-compose.yml` — add `corpus` service (build, host port 8010:8000, restart). Add `GATEWAY_URL`/`GATEWAY_TOKEN` env to `room-agent`.
- `gateway/seed/seed.py` — register `corpus` MCP server (`http://corpus:8000/mcp`).
- `a2a-agents/room/vote.py` — add `parse_threshold(note)` + `vote_with_corpus(amount, stance, seed, note)` (pure, tested).
- `a2a-agents/room/agent_executor.py` — fetch the owner's corpus via the gateway, then `vote_with_corpus`. Add httpx + gateway env. Tolerate failure → stance.
- `a2a-agents/room/Dockerfile` — add `httpx` (room voter now makes gateway calls).
- `companion/app.py` — Join `note` field → store `CORPUS[initials]` + POST to the corpus server; `/api/corpus/<owner>` (raw, for evidence); the Join UI gets a note textarea; the WALL renders discovered `room-*` agents + stance from `/a2a`.

## Unit L — corpus MCP server + Companion note plumbing
- `mcp-servers/corpus/server.py` (FastMCP, mirrors sales-tax shape):
  - `STORE = {}`; `@mcp.tool def get_corpus(owner: str) -> str: return STORE.get(owner.upper(), "")`.
  - `@mcp.custom_route("/set", ["POST"])` reads JSON `{owner, note}` → `STORE[owner.upper()] = note`; returns ok.
  - `@mcp.custom_route("/health", ["GET"])`.
  - `mcp.run(transport="http", host="0.0.0.0", port=8000)`.
- compose `corpus` service (8010:8000); seed registers `corpus`.
- Companion: `CORPUS = {}`; Join handler stores `CORPUS[initials]=note` AND `httpx.post(CORPUS_WRITE_URL+"/set", json={owner:initials, note})` (CORPUS_WRITE_URL default `http://localhost:8010`); `/api/corpus/<owner>` returns `{owner, note}`; Join UI adds a `<textarea id="note">`.
- Verify: Join with a note → `get_corpus` via gateway returns it; if the note has an SSN/card, the gateway-read output is redacted.

## Unit M — voter reads corpus, votes per note
- `vote.py`: `parse_threshold(note)` (first `$?\d[\d,]*k?` → dollars, `k`→×1000); `vote_with_corpus(amount, stance, seed, note)` per the convention above; keep `vote_expense`/`decide_vote` for the no-corpus path. Unit-test the new logic.
- `agent_executor.py`: parse owner from `agent=room-<stance>-<initials>` → initials; call gateway `/rpc` `corpus-get-corpus` with `{owner: initials}` (lowercase tool name); on success use the governed note via `vote_with_corpus`; on any error → `decide_vote` (stance). Return `VOTE=... :: <reason incl. note rule>`.
- room-agent Dockerfile: add httpx; compose: GATEWAY_URL + GATEWAY_TOKEN.
- Verify: join `room-strict-MG` with note "reject over $20000"; the chair quorum shows MG's voter rejecting on a $50k wire with reason citing the note; a $5k baseline (if run) shows MG approving (under cap). Fixed voters fall back to stance.

## Unit N — wall shows discovered A2A agents + stance
- Companion: extend `/api/mesh` (or add `/api/agents-detail`) to return `[{name, initials, stance}]` for `room-*` from `/a2a`.
- WALL `tick()`: render each agent as a stance-colored chip (strict=red, lenient=green, random=amber). Label: "A2A voting agents discovered in the governed mesh".

## Verify (whole feature)
- `cd a2a-agents/room && uv run --with pytest pytest test_vote.py -q` green.
- Live: join 3 attendees with different notes (one with PII + a $ cap); run the chair quorum → voters vote per their notes; show one corpus read is PII-redacted (governed); OPA blocks the wire. Wall shows agents + stance. Screenshot each.
- `make verify-controls` still green.
