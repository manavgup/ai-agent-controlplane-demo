# A2A Quorum — "Policy Beats Consensus" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let attendees create real, governed A2A voter agents (name + stance) in ContextForge's own catalog, then run a quorum where an expense fans out to every room agent through the gateway and the $50k Acme wire is BLOCKED by OPA regardless of the vote.

**Architecture:** A new shared A2A backend (`a2a-agents/room/`, Python `a2a-sdk`, mirroring the existing `auditor`) serves one `vote_expense` skill; one process backs many catalog entries (the proven `?agent=` uniqueness trick). The Companion registers each attendee as an A2A agent (`POST /a2a`), stores their stance, and a new `quorum` scenario fans a vote prompt out to every `a2a-room-*` tool via `/rpc` (so every call is authn'd + audited), tallies, then attempts the wire — which OPA denies at the $10k cap.

**Tech Stack:** Python 3.12, `a2a-sdk[http-server]==1.1.0` (Starlette + uvicorn), Flask Companion, ContextForge gateway (`/rpc`, `/a2a`), OPA (Rego), docker compose, bash money-shot assertions.

---

## Key facts established from the codebase (do not re-derive)

- **A2A registration** (`gateway/seed/seed.py:77-96`): `POST /a2a` with body `{"agent": {"name", "endpoint_url", "agent_type": "jsonrpc", "description", "tags": [...]}}`. This auto-creates a callable tool named `a2a-<name>` (e.g. `auditor` → `a2a-auditor`, confirmed by `scripts/money-shots/run-all.sh`).
- **Calling an A2A tool** through the gateway (proven, `companion/app.py:251-270` `s_a2a`): `rpc("a2a-<name>", {"message": {"role": "ROLE_USER", "parts": [{"text": "<prompt>"}], "messageId": "<id>"}})`. The Python agent reads it back with `a2a.helpers.get_message_text(context.message)`.
- **The Companion holds the gateway ADMIN token** (`make companion` sets `GATEWAY_TOKEN=$ADMIN`), so every catalog tool is callable via `/rpc` directly — no virtual-server grant is needed for the quorum.
- **OPA wire cap** (`gateway/policies/finops.rego:32-41`): `amount >= 10000` without `approval == true` → deny, message contains `Plugin Violation` and `T&E policy`. The canonical money shot is `erp-payments-wire {"payee":"Acme LLC","amount":50000,"approval":false}` → BLOCKED.
- **The `rpc()` helper** (`companion/app.py:55-66`) hardcodes `timeout=30`; we add an optional `timeout` arg for fast per-vote calls.
- **Tool name for the wire** is `erp-payments-wire`; receipts are `expense-db-get-receipt`.
- **The auditor is the structural template** for the new agent: `a2a-agents/auditor/__main__.py` (card + routes + uvicorn) and `agent_executor.py` (executor that emits Working → artifact → Completed).
- **Existing room-registration** (`companion/app.py:376-431`) currently registers attendees as MCP **gateways** pointing at `sales-tax`. We repurpose this path to register **A2A agents** pointing at the new `room-agent`. The separate `make salestax-*` / Stage-1-2 "Bob builds `add_tax`" beat is a different code path and stays untouched.

## Divergences from the spec (deliberate, noted here)

1. **Finale amount is $50,000 to Acme LLC** (not the spec's illustrative $12k). This matches the established demo money shot and OPA's $10k cap, so the BLOCK is the proven deterministic one.
2. **Stances are amount-driven** (intuitive for a finance room), refining the spec's approval-flag wording: `strict` rejects wires ≥ $10k; `lenient` approves up to $100k; `random` is a deterministic coin. On the $50k finale this yields a mixed, approve-leaning tally → "the room said yes, policy said no."
3. **No bespoke quorum JS panel.** The quorum returns the same `{verdict, headline, detail}` shape every scenario returns, so the existing card renderer (`companion/app.py:803-812`) displays the vote breakdown. Less code, lower stage risk.
4. **`room-agent` is a base-compose service** (always up via `make up`, like `auditor`/`payments`), not an ad-hoc override like `sales-tax`. Simpler and matches "always-on A2A citizen."

---

## File Structure

**Create:**
- `a2a-agents/room/vote.py` — pure voting + message parsing (no `a2a-sdk` import → unit-testable). Owns: `vote_expense`, `decide_vote`, parse helpers, thresholds.
- `a2a-agents/room/test_vote.py` — pytest for the pure logic.
- `a2a-agents/room/agent_executor.py` — `RoomVoterExecutor` (a2a-sdk executor; thin wrapper over `decide_vote`).
- `a2a-agents/room/__main__.py` — agent card + JSON-RPC routes + `/health`, uvicorn on `:8000`.
- `a2a-agents/room/Dockerfile` — mirrors `a2a-agents/auditor/Dockerfile`.
- `scripts/money-shots/quorum.sh` — headless proof: registers two ephemeral A2A voters, asserts a mixed tally + a BLOCKED $50k wire, cleans up.

**Modify:**
- `docker-compose.yml` — add the `room-agent` service.
- `companion/app.py` — config (`AGENT_PREFIX`, `AGENT_BACKEND_URL`, `ROOM_STANCES`, `STANCES`), `rpc()` timeout arg, `_a2a_agents()`/`_room_agent_names()` read `/a2a`, `register_agent()` → `POST /a2a` + stance, `_seed_demo_room_agents()`, `s_quorum()` + `SCENARIOS`, dashboard `SCEN`/stance `<select>`/`registerAgent()`.
- `scripts/money-shots/run-all.sh` — call `quorum.sh` so `make verify-controls` covers it.
- `scripts/agents-reset.sh` — also clear `room-*` from `/a2a`.
- `Makefile` — `roomagent-ensure` target; point `companion:` at it; `verify-quorum` convenience target; add new names to `.PHONY`.
- `README.md` — one row documenting the quorum scenario.
- `docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md` — append the divergence note.

---

## Task 1: Pure voting logic (`vote.py`) — TDD

**Files:**
- Create: `a2a-agents/room/vote.py`
- Test: `a2a-agents/room/test_vote.py`

- [ ] **Step 1: Write the failing tests**

Create `a2a-agents/room/test_vote.py`:

```python
"""Unit tests for the pure room-voter logic (no a2a-sdk, no network)."""

from vote import (
    LENIENT_THRESHOLD,
    STRICT_THRESHOLD,
    decide_vote,
    vote_expense,
)


def test_strict_rejects_the_50k_finale():
    assert vote_expense(50000, "strict")[0] == "reject"


def test_strict_approves_a_small_wire():
    assert vote_expense(500, "strict")[0] == "approve"


def test_strict_threshold_is_inclusive():
    assert vote_expense(STRICT_THRESHOLD, "strict")[0] == "reject"
    assert vote_expense(STRICT_THRESHOLD - 1, "strict")[0] == "approve"


def test_lenient_approves_the_50k_finale():
    assert vote_expense(50000, "lenient")[0] == "approve"


def test_lenient_rejects_the_implausibly_large():
    assert vote_expense(LENIENT_THRESHOLD, "lenient")[0] == "reject"


def test_random_is_deterministic_per_seed():
    assert vote_expense(50000, "random", seed="room-MG") == vote_expense(
        50000, "random", seed="room-MG"
    )


def test_random_reaches_both_outcomes_across_seeds():
    # Fixed seeds → deterministic, but verifies both branches are reachable
    # (so a real room produces a mixed tally, not a stuck vote).
    outcomes = {vote_expense(50000, "random", seed=f"room-{i}")[0] for i in range(20)}
    assert outcomes == {"approve", "reject"}


def test_unknown_stance_falls_back_to_random():
    assert vote_expense(50000, "banana", seed="x") == vote_expense(
        50000, "random", seed="x"
    )


def test_decide_vote_parses_a_prompt_and_emits_a_token():
    out = decide_vote(
        "Vote on expense. payee=Acme LLC amount=50000 approval=false "
        "stance=strict agent=room-MG."
    )
    assert out.startswith("VOTE=reject ::")


def test_decide_vote_lenient_approves_50k():
    out = decide_vote("amount=50000 approval=false stance=lenient agent=room-LN")
    assert out.startswith("VOTE=approve ::")


def test_decide_vote_defaults_to_random_when_stance_missing():
    out = decide_vote("amount=50000 agent=room-X")
    assert out.split(" ")[0] in ("VOTE=approve", "VOTE=reject")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
cd a2a-agents/room && uv run --with pytest pytest test_vote.py -q
```
Expected: FAIL — `ModuleNotFoundError: No module named 'vote'`.

- [ ] **Step 3: Write the implementation**

Create `a2a-agents/room/vote.py`:

```python
"""Pure voting logic for the room A2A voter agents.

No network, no a2a-sdk import — so it unit-tests in isolation and is
deterministic on stage (no wall-clock / random entropy). The executor in
agent_executor.py is a thin wrapper over decide_vote().
"""

import hashlib
import re

# Demo knobs (amount-driven so the tally is intuitive for a finance room).
STRICT_THRESHOLD = 10_000  # a strict agent rejects wires >= this (matches OPA cap)
LENIENT_THRESHOLD = 100_000  # a lenient agent rejects only the truly implausible


def vote_expense(amount, stance, seed=""):
    """Return (vote, reason); vote is 'approve' or 'reject'.

    strict  — reject if amount >= STRICT_THRESHOLD
    lenient — reject only if amount >= LENIENT_THRESHOLD
    random  — deterministic ~50/50 from hash(seed, amount)
    Unknown stance falls back to 'random'.
    """
    stance = (stance or "random").strip().lower()
    try:
        amount = float(amount)
    except (TypeError, ValueError):
        amount = 0.0

    if stance == "strict":
        if amount >= STRICT_THRESHOLD:
            return "reject", f"strict: ${amount:,.0f} >= ${STRICT_THRESHOLD:,} cap"
        return "approve", f"strict: ${amount:,.0f} under ${STRICT_THRESHOLD:,} cap"

    if stance == "lenient":
        if amount >= LENIENT_THRESHOLD:
            return "reject", f"lenient: ${amount:,.0f} is implausibly large"
        return "approve", f"lenient: ${amount:,.0f} looks fine"

    # random (deterministic): hash the seed + amount so the same agent always
    # votes the same way on the same expense, but the room as a whole is mixed.
    digest = hashlib.sha256(f"{seed}:{amount:.0f}".encode()).hexdigest()
    if int(digest[:8], 16) % 2 == 0:
        return "approve", "random: coin landed approve"
    return "reject", "random: coin landed reject"


def parse_amount(text):
    """Pull the expense amount out of a vote prompt.

    Prefers an explicit `amount=...`; falls back to the first dollar-ish number.
    """
    m = re.search(r"amount=\$?([\d,]+(?:\.\d+)?)", text)
    if not m:
        m = re.search(r"\$?\s*(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)", text)
    return float(m.group(1).replace(",", "")) if m else 0.0


def parse_stance(text):
    m = re.search(r"stance=(\w+)", text, re.IGNORECASE)
    return m.group(1).lower() if m else "random"


def parse_seed(text):
    m = re.search(r"agent=([\w.-]+)", text)
    return m.group(1) if m else ""


def decide_vote(text):
    """message text -> 'VOTE=<approve|reject> :: <reason>'.

    The delimited token is grep-friendly for the Companion, which stringifies
    the whole bridged JSON-RPC response and searches for it.
    """
    text = text or ""
    vote, reason = vote_expense(
        parse_amount(text), parse_stance(text), seed=parse_seed(text)
    )
    return f"VOTE={vote} :: {reason}"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
cd a2a-agents/room && uv run --with pytest pytest test_vote.py -q
```
Expected: PASS (11 passed).

- [ ] **Step 5: Commit**

```bash
git add a2a-agents/room/vote.py a2a-agents/room/test_vote.py
git commit -m "feat(room-agent): pure vote_expense + decide_vote logic with tests"
```

---

## Task 2: Room A2A server (executor + entrypoint)

**Files:**
- Create: `a2a-agents/room/agent_executor.py`
- Create: `a2a-agents/room/__main__.py`

These mirror `a2a-agents/auditor/` exactly in structure; only the skill body differs (vote instead of pay).

- [ ] **Step 1: Write the executor**

Create `a2a-agents/room/agent_executor.py`:

```python
"""Room voter agent executor.

Reads the vote prompt from the user message, computes a vote with the pure
decide_vote() logic, and returns it as a single text artifact. The Companion
passes the attendee's stance and the expense inside the prompt, so this agent
holds no per-attendee state — one process backs every catalog entry.
"""

from a2a.helpers import (
    get_message_text,
    new_task_from_user_message,
    new_text_message,
    new_text_part,
)
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.tasks import TaskUpdater
from a2a.types.a2a_pb2 import TaskState

from vote import decide_vote


class RoomVoterExecutor(AgentExecutor):
    """A2A executor: turns a vote prompt into 'VOTE=approve|reject :: reason'."""

    async def execute(
        self,
        context: RequestContext,
        event_queue: EventQueue,
    ) -> None:
        if context.current_task:
            task = context.current_task
        else:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)

        task_updater = TaskUpdater(
            event_queue=event_queue, task_id=task.id, context_id=task.context_id
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_WORKING,
            message=new_text_message("Voting on expense..."),
        )

        query = get_message_text(context.message) or ""
        result = decide_vote(query)
        print("Room voter result:", result)

        await task_updater.add_artifact(
            parts=[new_text_part(text=result, media_type="text/plain")]
        )
        await task_updater.update_status(
            state=TaskState.TASK_STATE_COMPLETED,
            message=new_text_message("Vote complete."),
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError("Cancel is not supported.")
```

- [ ] **Step 2: Write the entrypoint**

Create `a2a-agents/room/__main__.py`:

```python
"""Entrypoint for the Room Voter A2A agent.

One process serves the agent card at /.well-known/agent-card.json, a JSON-RPC
endpoint at '/', and a plain /health probe, bound to 0.0.0.0:8000. ContextForge
registers many catalog entries that all point here (distinguished by a ?agent=
query suffix that this server ignores), so the whole room shares one backend.
"""

import uvicorn

from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route

from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCapabilities, AgentCard, AgentInterface, AgentSkill

from agent_executor import RoomVoterExecutor

HOST = "0.0.0.0"
PORT = 8000


def build_agent_card() -> AgentCard:
    skill = AgentSkill(
        id="vote_expense",
        name="vote_expense",
        description=(
            "Votes approve/reject on an expense according to a voting stance "
            "carried in the request (strict / lenient / random)."
        ),
        tags=["vote", "expense", "quorum"],
        examples=[
            "Vote on expense. payee=Acme LLC amount=50000 stance=strict",
            "Vote on expense. payee=Corner Cafe amount=500 stance=lenient",
        ],
        input_modes=["text/plain"],
        output_modes=["text/plain"],
    )
    return AgentCard(
        name="Room Voter Agent",
        description="An attendee-created voter in the expense-approval quorum.",
        version="0.1.0",
        default_input_modes=["text/plain"],
        default_output_modes=["text/plain"],
        capabilities=AgentCapabilities(streaming=True),
        supported_interfaces=[
            AgentInterface(
                protocol_binding="JSONRPC",
                url=f"http://{HOST}:{PORT}",
            )
        ],
        skills=[skill],
    )


async def health(_request: Request) -> JSONResponse:
    return JSONResponse({"status": "ok", "server": "room-agent"})


def build_app() -> Starlette:
    public_agent_card = build_agent_card()
    request_handler = DefaultRequestHandler(
        agent_executor=RoomVoterExecutor(),
        task_store=InMemoryTaskStore(),
        agent_card=public_agent_card,
    )
    routes = [Route("/health", health, methods=["GET"])]
    routes.extend(create_agent_card_routes(public_agent_card))
    routes.extend(create_jsonrpc_routes(request_handler, "/"))
    return Starlette(routes=routes)


def main() -> None:
    uvicorn.run(build_app(), host=HOST, port=PORT)


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Commit**

```bash
git add a2a-agents/room/agent_executor.py a2a-agents/room/__main__.py
git commit -m "feat(room-agent): a2a-sdk voter server (card + JSON-RPC + health)"
```

> Note: this server is exercised end-to-end in Task 3 (container) and Task 7 (headless proof). It imports `a2a-sdk`, which is installed in the image, so it is not run on the host here.

---

## Task 3: Containerize + add to the mesh

**Files:**
- Create: `a2a-agents/room/Dockerfile`
- Modify: `docker-compose.yml` (add `room-agent` service after `payments`, around line 91-95)

- [ ] **Step 1: Write the Dockerfile**

Create `a2a-agents/room/Dockerfile` (mirrors `a2a-agents/auditor/Dockerfile`; no `httpx` — this agent makes no outbound calls):

```dockerfile
FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir "a2a-sdk[http-server]==1.1.0" uvicorn

COPY . .

EXPOSE 8000

CMD ["python", "__main__.py"]
```

- [ ] **Step 2: Add the service to docker-compose.yml**

In `docker-compose.yml`, immediately after the `payments` service block (currently ends ~line 95), add:

```yaml
  room-agent:
    build: ./a2a-agents/room
    ports:
      - "9100:8000"   # exposed for the A2A inspector + a host health probe
    restart: unless-stopped
```

- [ ] **Step 3: Build and run, verify the agent serves**

Run:
```bash
docker compose up -d --build room-agent
sleep 4
curl -s localhost:9100/health
```
Expected: `{"status":"ok","server":"room-agent"}`

Then verify the card and a direct vote (bypassing the gateway, raw A2A):
```bash
curl -s localhost:9100/.well-known/agent-card.json | head -c 200
curl -s -X POST localhost:9100/ -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"message/send","params":{"message":{"role":"ROLE_USER","parts":[{"text":"amount=50000 stance=strict agent=room-SMOKE"}],"messageId":"smoke-1"}}}' | grep -o 'VOTE=[a-z]*'
```
Expected: the card JSON shows `"name":"Room Voter Agent"`, and the vote call returns `VOTE=reject`.

> If `message/send` is not the method name your `a2a-sdk` build expects, list methods from the card's `supported_interfaces`/protocol or check `a2a-agents/auditor` runtime logs — the gateway bridge (Task 7) is the authoritative path; this raw curl is only a smoke test.

- [ ] **Step 4: Commit**

```bash
git add a2a-agents/room/Dockerfile docker-compose.yml
git commit -m "feat(room-agent): containerize + add to the compose mesh"
```

---

## Task 4: Companion — register attendees as A2A voters (+ stance, + demo seeds)

**Files:**
- Modify: `companion/app.py` — config block (lines 36-41), `rpc()` (55-66), room helpers (333-373), `register_agent()` (376-431); add `_a2a_agents()` and `_seed_demo_room_agents()`.

- [ ] **Step 1: Update the config block**

Replace `companion/app.py:36-41` (the `AGENT_PREFIX` / `AGENT_BACKEND_URL` block) with:

```python
# ── room agent registration: each attendee names an A2A voter and picks a stance;
# it really registers with ContextForge's /a2a catalog (the count + wall climb).
# All point at the one shared room-agent backend; a unique ?agent= query suffix
# keeps each catalog URL distinct (the backend ignores the query). The attendee's
# stance is held here and passed in each vote call, so the backend stays stateless.
AGENT_PREFIX = "room"
AGENT_BACKEND_URL = os.environ.get("AGENT_BACKEND_URL", "http://room-agent:8000/")
STANCES = ("strict", "lenient", "random")
ROOM_STANCES = {}  # agent name -> stance, populated at registration + demo-seed time
```

- [ ] **Step 2: Give `rpc()` a timeout argument**

Replace the `rpc` definition (`companion/app.py:55-66`) with:

```python
def rpc(name, arguments, timeout=30):
    body = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": name, "arguments": arguments},
    }
    try:
        r = httpx.post(f"{GW}/rpc", headers=H, json=body, timeout=timeout)
        return r.json()
    except Exception as e:
        return {"error": {"message": f"gateway unreachable: {e}"}}
```

- [ ] **Step 3: Point the room helpers at `/a2a` instead of `/gateways`**

Replace the helper block `companion/app.py:334-350` (`_gateways` + `_room_agent_names`) with:

```python
# ── room agent registration ─────────────────────────────────────────────────
def _a2a_agents():
    """Registered A2A agents in the ContextForge catalog."""
    try:
        a = httpx.get(f"{GW}/a2a", headers=H, timeout=10).json()
        return a if isinstance(a, list) else []
    except Exception:
        return []


def _room_agent_names(agents=None):
    """Names of voter agents the room built this session, newest last."""
    agents = _a2a_agents() if agents is None else agents
    return [
        a.get("name", "")
        for a in agents
        if isinstance(a, dict) and a.get("name", "").startswith(AGENT_PREFIX + "-")
    ]
```

Leave `_sanitize_initials` (353-355), `_initials_of` (358-363), and `_unique_name` (366-373) unchanged — they already key off `AGENT_PREFIX`, so they now produce `room-MG` → `MG`.

- [ ] **Step 4: Rewrite `register_agent()` to register an A2A voter with a stance**

Replace `companion/app.py:376-431` (the whole `register_agent` function) with:

```python
@app.route("/api/register-agent", methods=["GET", "POST"])
def register_agent():
    """Register a uniquely-named A2A voter with ContextForge's /a2a catalog, so
    the live count climbs. Stores the attendee's stance; dedups the name."""
    initials = _sanitize_initials(
        request.values.get("initials") or request.values.get("ini")
    )
    stance = (request.values.get("stance") or "random").strip().lower()
    if stance not in STANCES:
        stance = "random"
    last_err = None
    for _ in range(10):
        existing = {a.get("name", "") for a in _a2a_agents()}
        name = _unique_name(initials, existing)
        # ContextForge keys A2A agents by name; carry the unique name as a query
        # suffix on the shared backend url so each catalog entry is distinct and
        # the backend (which ignores the query) still serves JSON-RPC at '/'.
        sep = "&" if "?" in AGENT_BACKEND_URL else "?"
        agent_url = f"{AGENT_BACKEND_URL}{sep}agent={name}"
        try:
            r = httpx.post(
                f"{GW}/a2a",
                headers=H,
                timeout=30,
                json={
                    "agent": {
                        "name": name,
                        "endpoint_url": agent_url,
                        "agent_type": "jsonrpc",
                        "description": f"room voter built by {initials} (stance {stance})",
                        "tags": ["finbyte", "room"],
                    }
                },
            )
            if r.status_code < 300:
                ROOM_STANCES[name] = stance
                return jsonify(
                    {
                        "ok": True,
                        "name": name,
                        "initials": initials,
                        "stance": stance,
                        "count": len(_room_agent_names()),
                    }
                )
            last_err = f"{r.status_code} {r.text[:160]}"
            # Retry ONLY on a name collision (the next scan advances the suffix);
            # any other status is deterministic — fail fast instead of hammering.
            blob = r.text.lower()
            if r.status_code != 409 and "already exists" not in blob:
                if "dns" in blob or "ssrf" in blob:
                    last_err = "room-agent backend unreachable — run `make up`"
                break
        except Exception as e:
            last_err = str(e)
            break
    return (
        jsonify(
            {"ok": False, "error": last_err or "register failed", "initials": initials}
        ),
        502,
    )
```

- [ ] **Step 5: Add the demo-seed helper and call it at startup**

Add this function immediately after `register_agent` (so `_unique_name`/`ROOM_STANCES` are in scope), e.g. after line 431:

```python
def _seed_demo_room_agents():
    """Register two demo voters so the quorum is never empty (idempotent).

    room-demo-strict rejects the $50k finale; room-demo-lenient approves it — so
    even with zero attendees the tally is mixed and the OPA block still lands.
    """
    seeds = {"strict": "demostrict", "lenient": "demolenient"}
    existing = {a.get("name", "") for a in _a2a_agents()}
    for stance, initials in seeds.items():
        name = _unique_name(initials, existing)
        if name in ROOM_STANCES:
            continue
        sep = "&" if "?" in AGENT_BACKEND_URL else "?"
        try:
            r = httpx.post(
                f"{GW}/a2a",
                headers=H,
                timeout=30,
                json={
                    "agent": {
                        "name": name,
                        "endpoint_url": f"{AGENT_BACKEND_URL}{sep}agent={name}",
                        "agent_type": "jsonrpc",
                        "description": f"demo room voter (stance {stance})",
                        "tags": ["finbyte", "room", "demo"],
                    }
                },
            )
            if r.status_code < 300 or "already exists" in r.text.lower():
                ROOM_STANCES[name] = stance
                existing.add(name)
        except Exception:
            pass  # best-effort; the quorum still runs with whatever registered
```

Then find the app entrypoint at the bottom of `companion/app.py` (the `if __name__ == "__main__":` / `app.run(...)` block) and call the seeder just before the server starts. For example:

```python
if __name__ == "__main__":
    _seed_demo_room_agents()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "7070")))
```

(Match the existing `app.run` arguments already present in the file — only add the `_seed_demo_room_agents()` line above it.)

- [ ] **Step 6: Verify registration lands in `/a2a`**

With the stack up and the gateway seeded (`make up && make seed`), and an admin token minted, run the Companion briefly or hit the endpoint via a short Python check. Simplest manual verification:
```bash
# from a shell where GATEWAY_TOKEN is an admin token and GW=http://localhost:4444
curl -s -X POST "localhost:7070/api/register-agent?initials=MG&stance=strict" | python3 -m json.tool
```
Expected: `{"ok": true, "name": "room-MG", "stance": "strict", "count": >=1 ...}` and `room-MG` now appears in `curl -s localhost:4444/a2a -H "Authorization: Bearer $TOKEN"`.

> This requires the Companion running (`make companion`). If you are batching, defer this manual check to Task 7's headless proof, which exercises the same `/a2a` registration path without the browser.

- [ ] **Step 7: Commit**

```bash
git add companion/app.py
git commit -m "feat(companion): register attendees as A2A voters with a stance"
```

---

## Task 5: Companion — the quorum scenario

**Files:**
- Modify: `companion/app.py` — add `s_quorum()` near the other `s_*` scenarios (after `s_a2a`, ~line 271); add the `quorum` entry to `SCENARIOS` (273-280); add the `concurrent.futures` import.

- [ ] **Step 1: Add the import**

At the top of `companion/app.py`, alongside the existing stdlib imports (`import io`, `import json`, ...), add:

```python
import concurrent.futures
```

- [ ] **Step 2: Add `s_quorum()` after `s_a2a` (after line 270)**

```python
QUORUM_PAYEE = "Acme LLC"
QUORUM_AMOUNT = 50000  # matches the OPA $10k cap money shot -> BLOCKED w/o approval


def _vote_one(name):
    """Fan a vote prompt to one room agent through the gateway; return its vote.

    Robust by design: any gateway/transport error -> 'abstain' (never raises),
    so one slow or dead attendee agent can't sink the tally.
    """
    stance = ROOM_STANCES.get(name, "random")
    prompt = (
        f"Vote on expense. payee={QUORUM_PAYEE} amount={QUORUM_AMOUNT} "
        f"approval=false stance={stance} agent={name}."
    )
    resp = rpc(
        f"a2a-{name}",
        {
            "message": {
                "role": "ROLE_USER",
                "parts": [{"text": prompt}],
                "messageId": f"q-{name}",
            }
        },
        timeout=8,
    )
    blob = json.dumps(resp)
    if "VOTE=approve" in blob:
        vote = "approve"
    elif "VOTE=reject" in blob:
        vote = "reject"
    else:
        vote = "abstain"
    return {"agent": _initials_of(name), "stance": stance, "vote": vote}


def s_quorum():
    names = _room_agent_names()
    votes = []
    if names:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            futures = {pool.submit(_vote_one, n): n for n in names}
            for fut in concurrent.futures.as_completed(futures, timeout=20):
                try:
                    votes.append(fut.result())
                except Exception:
                    votes.append(
                        {
                            "agent": _initials_of(futures[fut]),
                            "stance": ROOM_STANCES.get(futures[fut], "random"),
                            "vote": "abstain",
                        }
                    )

    approve = sum(1 for v in votes if v["vote"] == "approve")
    reject = sum(1 for v in votes if v["vote"] == "reject")
    abstain = sum(1 for v in votes if v["vote"] == "abstain")

    # The payoff: attempt the wire the room (maybe) approved. OPA blocks it at the
    # $10k cap regardless of the vote — policy beats consensus.
    wire_name = "erp-payments-wire"
    wire_args = {"payee": QUORUM_PAYEE, "amount": QUORUM_AMOUNT, "approval": False}
    wire = rpc(wire_name, wire_args)
    wtext, werr = text_of(wire)
    blocked = "Plugin Violation" in json.dumps(wire)

    lines = [f"  {v['agent']:<10} {v['stance']:<8} → {v['vote']}" for v in votes]
    detail = (
        f"Room voted on a ${QUORUM_AMOUNT:,} wire to {QUORUM_PAYEE}:\n"
        + ("\n".join(lines) if lines else "  (no room agents registered)")
        + f"\n\n  TALLY  approve={approve}  reject={reject}  abstain={abstain}\n\n"
        + (
            f"  Wire attempted anyway → {werr or wtext}"
            if blocked
            else f"  Wire result → {wtext or werr}"
        )
    )
    return dict(
        verdict="BLOCKED" if blocked else "SEE RAW",
        blocked=blocked,
        headline=(
            f"{approve} approve / {reject} reject — OPA blocked the ${QUORUM_AMOUNT:,} "
            "wire anyway (policy beats consensus)"
        ),
        detail=detail,
        raw=wire,
        request={"name": wire_name, "arguments": wire_args},
    )
```

- [ ] **Step 3: Register the scenario in `SCENARIOS`**

In the `SCENARIOS` dict (`companion/app.py:273-280`), add a `quorum` entry as the last item:

```python
    "quorum": ("Expense approval quorum — policy beats consensus", s_quorum),
```

- [ ] **Step 4: Verify the scenario end-to-end**

With the stack up + seeded and the Companion running (`make companion`), and at least the demo agents seeded:
```bash
curl -s localhost:7070/api/run/quorum | python3 -m json.tool
```
Expected: `"verdict": "BLOCKED"`, `"blocked": true`, a `detail` listing each demo voter's vote with a TALLY line, and a headline ending "policy beats consensus".

> Defer to Task 7 if batching — the headless proof asserts the same path deterministically.

- [ ] **Step 5: Commit**

```bash
git add companion/app.py
git commit -m "feat(companion): quorum scenario — fan-out votes then OPA blocks the wire"
```

---

## Task 6: Companion UI — stance dropdown + quorum card

**Files:**
- Modify: `companion/app.py` — the inline `PAGE` template: `SCEN` array (790-792), the `.roombar` register form (775-779), the `registerAgent()` JS (865-873).

- [ ] **Step 1: Add the quorum card to the `SCEN` array**

In `companion/app.py:790-792`, append the quorum entry to the `SCEN` array (after the `a2a` entry):

```javascript
const SCEN=[["baseline","Baseline — small reimbursement"],["policy","#1 Policy — $50,000 wire (OPA amount cap)"],
 ["policy_approved","#1 Policy — $50,000 WITH dual approval"],["pii","#2 Data protection — PII + secret"],
 ["injection","#3 Prompt-injection — poisoned receipt"],["a2a","Cross-language A2A — Rust agent executes"],
 ["quorum","Expense approval quorum — policy beats consensus"]];
```

- [ ] **Step 2: Add a stance `<select>` to the register form**

In the `.roombar` block (`companion/app.py:775-779`), insert a stance dropdown between the `#ini` input and the Register button:

```html
     <div class="roomreg">
       <input id="ini" maxlength="5" placeholder="your initials" autocapitalize="characters" onkeydown="if(event.key==='Enter')registerAgent()">
       <select id="stance" title="how your agent votes">
         <option value="random">stance: random</option>
         <option value="strict">stance: strict</option>
         <option value="lenient">stance: lenient</option>
       </select>
       <button onclick="registerAgent()">Register my agent ▶</button>
       <span id="regout" class="small"></span>
     </div>
```

Add a style for the select so it matches the existing inputs — append inside the `.roomreg input{...}` area of the `<style>` block (near `companion/app.py:736-738`):

```css
 .roomreg select{background:#000;border:1px solid #393939;border-radius:6px;color:#fff;padding:8px 10px;font-size:13px;font-family:'IBM Plex Mono',monospace}
```

- [ ] **Step 3: Send the stance from `registerAgent()`**

Replace the `registerAgent()` function (`companion/app.py:865-873`) with:

```javascript
async function registerAgent(){
 const ini=document.getElementById('ini').value;
 const stance=document.getElementById('stance').value;
 const out=document.getElementById('regout'); out.textContent='registering…';
 try{
   const r=await (await fetch('/api/register-agent?initials='+encodeURIComponent(ini)+'&stance='+encodeURIComponent(stance),{method:'POST'})).json();
   if(r.ok){out.textContent='✓ '+r.name+' ('+r.stance+') — agents: '+r.count; document.getElementById('ini').value=''; pollAgents();}
   else out.textContent='⚠ '+(r.error||'failed');
 }catch(e){out.textContent='⚠ '+e;}
}
```

- [ ] **Step 4: Verify in the browser**

With `make companion` running, open `http://localhost:7070`:
- The register bar shows a stance dropdown.
- Registering with initials + a stance shows `✓ room-XX (strict) — agents: N` and the count climbs.
- A new card "Expense approval quorum — policy beats consensus" appears; clicking **Run** shows a BLOCKED verdict with the vote breakdown in the card body.

- [ ] **Step 5: Commit**

```bash
git add companion/app.py
git commit -m "feat(companion): stance dropdown + quorum card in the dashboard"
```

---

## Task 7: Headless proof + reset/Make wiring

**Files:**
- Create: `scripts/money-shots/quorum.sh`
- Modify: `scripts/money-shots/run-all.sh` (call quorum.sh), `scripts/agents-reset.sh` (clear `room-*`), `Makefile` (`roomagent-ensure`, `companion:` dep, `verify-quorum`, `.PHONY`).

- [ ] **Step 1: Write the headless quorum proof**

Create `scripts/money-shots/quorum.sh` (self-contained: registers two ephemeral A2A voters, asserts a mixed tally + a BLOCKED wire, then cleans them up):

```bash
#!/usr/bin/env bash
# Headless proof of the A2A quorum: two voters (strict rejects, lenient approves)
# disagree, and OPA blocks the $50k wire regardless. Registers + cleans up its
# own ephemeral agents so it is idempotent. Usage: bash scripts/money-shots/quorum.sh
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

GW=${GATEWAY_URL:-http://localhost:4444}
SECRET=${JWT_SECRET_KEY:-demo-only-change-me-0123456789abcdef}
TOKEN=$(DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- \
  python -m mcpgateway.utils.create_jwt_token -u admin@finbyte.demo --admin -e 10080 -s "$SECRET" 2>/dev/null | tail -1)
AUTH=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

register(){ # name, stance(unused server-side; carried in the vote prompt)
  curl -s "${AUTH[@]}" -X POST "$GW/a2a" -d "{\"agent\":{\"name\":\"$1\",\"endpoint_url\":\"http://room-agent:8000/?agent=$1\",\"agent_type\":\"jsonrpc\",\"description\":\"quorum test voter\",\"tags\":[\"room\",\"test\"]}}" >/dev/null
}
vote(){ # toolname, stance, agentname  -> echoes VOTE=...
  curl -s "${AUTH[@]}" -X POST "$GW/rpc" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":{\"message\":{\"role\":\"ROLE_USER\",\"parts\":[{\"text\":\"amount=50000 approval=false stance=$2 agent=$3\"}],\"messageId\":\"qt-$3\"}}}}"
}
unregister(){ # name
  local id
  id=$(curl -s "${AUTH[@]}" "$GW/a2a" | python3 -c "import sys,json;[print(a['id']) for a in json.load(sys.stdin) if isinstance(a,dict) and a.get('name')=='$1']" 2>/dev/null | head -1)
  [ -n "$id" ] && curl -s "${AUTH[@]}" -X DELETE "$GW/a2a/$id" >/dev/null
}

echo "== A2A quorum: voters disagree, OPA still blocks =="
register room-test-strict
register room-test-lenient
sleep 3  # let the gateway materialize the a2a-* tools

rs=$(vote a2a-room-test-strict strict room-test-strict)
rl=$(vote a2a-room-test-lenient lenient room-test-lenient)
printf '%s' "$rs" | grep -q "VOTE=reject"  && ok "strict voter REJECTS the \$50k wire" || no "strict voter should reject (got: $(printf '%s' "$rs" | head -c 120))"
printf '%s' "$rl" | grep -q "VOTE=approve" && ok "lenient voter APPROVES the \$50k wire" || no "lenient voter should approve (got: $(printf '%s' "$rl" | head -c 120))"

w=$(curl -s "${AUTH[@]}" -X POST "$GW/rpc" -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"erp-payments-wire","arguments":{"payee":"Acme LLC","amount":50000,"approval":false}}}')
printf '%s' "$w" | grep -qF "Plugin Violation" && ok "\$50k wire BLOCKED despite the vote (policy beats consensus)" || no "wire should be blocked (got: $(printf '%s' "$w" | head -c 120))"

unregister room-test-strict
unregister room-test-lenient

echo "  ── quorum: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] || exit 1
```

Make it executable:
```bash
chmod +x scripts/money-shots/quorum.sh
```

- [ ] **Step 2: Run it (the stack must be up + seeded, with room-agent built)**

```bash
make up && make seed
docker compose up -d --build room-agent
bash scripts/money-shots/quorum.sh
```
Expected: `quorum: 3 passed, 0 failed`.

> If the strict/lenient assertions fail because the gateway bridges arguments differently than the proven `message` envelope, inspect one raw response (`printf '%s' "$rs"`) and adjust `_vote_one` (Task 5) and this script together — they share the one contract. The wire-block assertion is independent and must pass regardless.

- [ ] **Step 3: Wire it into `make verify-controls`**

In `scripts/money-shots/run-all.sh`, just before the final `RESULT` echo block (the `echo "──…"` / `RESULT: $PASS passed` lines near the end), add:

```bash
echo "== A2A quorum (policy beats consensus) =="
if bash "$(dirname "$0")/quorum.sh"; then PASS=$((PASS+3)); else FAIL=$((FAIL+1)); fi
```

> Note: `quorum.sh` prints its own per-assertion lines and returns non-zero on any failure; this rolls its result into the suite's totals so `make verify-controls` stays one green gate.

- [ ] **Step 4: Clear `room-*` voters in `agents-reset.sh`**

Read `scripts/agents-reset.sh` first. It currently deletes `salestax-*` from `/gateways`. Add an equivalent pass that deletes `room-*` agents from `/a2a`. Append (adapting to the script's existing token + `$GW` variables):

```bash
# Also clear the A2A voter agents the room built (the quorum demo).
ROOM_IDS=$(curl -s "${AUTH[@]}" "$GW/a2a" | python3 -c "import sys,json;[print(a['id']) for a in json.load(sys.stdin) if isinstance(a,dict) and a.get('name','').startswith('room-')]" 2>/dev/null)
for id in $ROOM_IDS; do curl -s "${AUTH[@]}" -X DELETE "$GW/a2a/$id" >/dev/null; done
echo "cleared room-* A2A voters"
```

(Use whatever auth-header variable `agents-reset.sh` already defines; if it uses an inline `-H "Authorization: Bearer $TOKEN"`, match that form.)

- [ ] **Step 5: Add `roomagent-ensure` and point `companion:` at it**

In the `Makefile`, replace the `salestax-ensure` dependency on the `companion:` target (line 212) so the companion ensures the **room-agent** backend (its registration target) is up. Add a new target near `salestax-ensure` (after line 209):

```makefile
roomagent-ensure: ## (internal) make sure the room-agent A2A backend is running — quorum voters register against it
	@if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'room-agent'; then \
	  echo "✔ room-agent backend already up (A2A voter registration will resolve)"; \
	else \
	  echo "→ room-agent backend not running — starting it (the room's voters register against it)…"; \
	  $(COMPOSE) up -d --build room-agent || echo "!! room-agent didn't start — registration 422s until it's up: docker compose up -d room-agent"; \
	fi
```

Change line 212 from:
```makefile
companion: salestax-ensure ## Run the browser companion dashboard on :7070 (auto-ensures the sales-tax backend so registration works)
```
to:
```makefile
companion: roomagent-ensure ## Run the browser companion dashboard on :7070 (auto-ensures the room-agent A2A backend so voter registration works)
```

Add a convenience proof target near `verify-controls` (after line 447):

```makefile
verify-quorum: ## Prove just the A2A quorum (registers + cleans up its own voters)
	@bash scripts/money-shots/quorum.sh
```

Add `roomagent-ensure` and `verify-quorum` to the `.PHONY` line (line 34).

- [ ] **Step 6: Commit**

```bash
git add scripts/money-shots/quorum.sh scripts/money-shots/run-all.sh scripts/agents-reset.sh Makefile
git commit -m "test(quorum): headless proof + verify-controls/reset/Make wiring"
```

---

## Task 8: Docs — README row + spec divergence note

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md`

- [ ] **Step 1: Document the scenario in the README**

In `README.md`, find the scenarios/controls list (near the `expense-db` / tools table around line 44, or the scenario list the Companion mirrors). Add a row/bullet:

```markdown
- **Expense approval quorum** — attendees register A2A voter agents (name + stance) in ContextForge's own `/a2a` catalog; the `quorum` scenario fans an expense out to every voter through the gateway (each call authn'd + audited), then OPA blocks the $50k Acme wire regardless of the tally. **Policy beats consensus.**
```

- [ ] **Step 2: Append the divergence note to the spec**

In `docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md`, under "Open Questions" (or a new "Implementation notes" section at the end), add:

```markdown
## Implementation notes (reconciled during planning)

- Finale uses the canonical **$50,000 Acme LLC** wire (OPA $10k cap) rather than the illustrative $12k, so the BLOCK is the proven money shot.
- Stances are **amount-driven**: strict rejects ≥ $10k, lenient approves up to $100k, random is a deterministic per-agent coin. On the $50k finale this gives a mixed, approve-leaning tally.
- The quorum renders in the **standard scenario card** (returns `{verdict, headline, detail}`); no bespoke JS panel.
- `room-agent` is a **base docker-compose service** (always up via `make up`), not an ad-hoc override.
- The attendee voter backend is **stateless**: the Companion holds each agent's stance and passes it in the vote prompt; the gateway-derived tool is `a2a-room-<initials>`.
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md
git commit -m "docs: document the A2A quorum scenario + reconcile spec"
```

---

## Final verification (after all tasks)

- [ ] **Unit logic:** `cd a2a-agents/room && uv run --with pytest pytest test_vote.py -q` → all green.
- [ ] **Full headless gate:** `make up && make seed && docker compose up -d --build room-agent && make verify-controls` → `RESULT: 19 passed, 0 failed` (the original 16 + the 3 quorum assertions).
- [ ] **Live demo:** `make companion`, open `:7070`, register a couple of voters with different stances, **Run** the quorum card → BLOCKED with a mixed tally; the count + `/wall` climb.
- [ ] **Repeatable:** `make demo-reset` (or `bash scripts/agents-reset.sh`) clears `room-*` voters so the beat repeats clean.

---

## Self-Review

**Spec coverage:** Every spec component maps to a task — room-agent backend (T1-T3), join form name+stance → `/a2a` (T4, T6), `/api/run/quorum` fan-out through the gateway (T5), empty-room demo seeds (T4), per-vote timeout → abstain (T5 `_vote_one` + 8s timeout + ThreadPool), duplicate-name suffix (T4 `_unique_name`), tests (T1 unit + T7 integration), compose service (T3), reset (T7). The spec's "optional OPA source-agent stamp" remains explicitly out of scope (spec §Optional Stretch).

**Placeholder scan:** No TBD/TODO; every code step contains complete, runnable content. The only conditional guidance (raw-curl method name in T3, argument-bridging in T7) is framed as a verification fallback with the authoritative path named, not a placeholder for missing code.

**Type/name consistency:** `AGENT_PREFIX="room"` → catalog names `room-<initials>` → tools `a2a-room-<initials>` → `_room_agent_names()`/`_initials_of()`/`_vote_one()` all key off the same prefix. `decide_vote` returns `VOTE=<vote> ::` consumed identically by `_vote_one` (T5) and `quorum.sh` (T7). `vote_expense(amount, stance, seed)` signature matches across `vote.py`, `test_vote.py`, and `decide_vote`. Finale tool `erp-payments-wire` and block marker `Plugin Violation` match `s_policy` and the existing money shot.
