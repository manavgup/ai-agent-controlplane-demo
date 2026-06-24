# A2A Quorum — "Policy Beats Consensus" Implementation Plan (Hybrid)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A live, non-coder-friendly demo where the room votes on a $50k wire from their phones (instant local tally) AND a fixed set of real A2A voter agents votes through the ContextForge gateway (governed + audited) — then OPA blocks the wire regardless of either tally. Policy beats consensus.

**Architecture (hybrid, post-Codex review):** The crowd votes are recorded **locally in the Companion** (in-memory, cannot fail, no gateway calls, no public catalog writes). The "agents are real and governed" proof comes from a **fixed set of 5 A2A voter agents seeded once** at `make seed` time into ContextForge's `/a2a` catalog; the quorum fans a vote prompt to those 5 through `/rpc` (real, authn'd, audited). The finale attempts the $50k Acme wire and OPA denies it at the $10k cap.

**Tech Stack:** Python 3.12, `a2a-sdk[http-server]==1.1.0` (Starlette + uvicorn), Flask Companion, ContextForge gateway (`/rpc`, `/a2a`), OPA (Rego), docker compose, bash money-shot assertions.

---

## Why hybrid (the Codex review takeaways baked in)

The earlier draft minted a unique callable A2A catalog tool **per attendee phone on a public cloudflared tunnel**. Codex flagged this as the riskiest part of the demo, and for a non-coder room it buys nothing the audience cares about. The hybrid removes, by construction:

- **Tool-materialization races** — the gateway needs seconds to turn a `POST /a2a` into a callable `a2a-*` tool. Seeding 5 fixed voters at `make seed` (minutes before showtime) eliminates the race; an attendee tapping a phone never triggers a catalog write.
- **Fan-out latency at scale** — the agent quorum is always exactly 5 gateway calls, not 50+. Crowd size no longer affects timing.
- **Public catalog spam / abuse** — attendees never write to `/a2a`. They POST a local vote; the worst case is an inflated in-memory counter, capped and dedup'd.
- **The `as_completed` crash** — replaced with the bug-free `concurrent.futures.wait()` pattern (see Task 6).
- **Restart fragility** — fixed voters carry their stance **in the agent name** (`room-strict-1`), read back deterministically; no in-memory stance map to lose.

What survives intact: real A2A agents, real agent cards, real governed gateway calls, OPA blocking the wire, and live audience participation. The story is unchanged: the room said yes, the agents said yes, policy said no.

## Established codebase facts (do not re-derive)

- **A2A registration** (`gateway/seed/seed.py:77-96`): `POST /a2a` with `{"agent": {"name", "endpoint_url", "agent_type": "jsonrpc", "description", "tags"}}` auto-creates a callable tool `a2a-<name>` (confirmed: `auditor` → `a2a-auditor`, `payments` → `a2a-payments` in `scripts/money-shots/run-all.sh`).
- **Calling an A2A tool** (proven, `companion/app.py:251-270` `s_a2a`): `rpc("a2a-<name>", {"message": {"role": "ROLE_USER", "parts": [{"text": "<prompt>"}], "messageId": "<id>"}})`. The Python agent reads it with `a2a.helpers.get_message_text(context.message)`.
- **Companion holds the gateway ADMIN token** (`make companion` sets `GATEWAY_TOKEN=$ADMIN`), so any catalog tool is callable via `/rpc`. No virtual-server grant needed.
- **OPA wire cap** (`gateway/policies/finops.rego:32-41`): `amount >= 10000` without `approval == true` → deny; message contains `Plugin Violation` and `T&E policy`. Canonical money shot: `erp-payments-wire {"payee":"Acme LLC","amount":50000,"approval":false}` → BLOCKED.
- **`rpc()` helper** (`companion/app.py:55-66`) hardcodes `timeout=30`; we add an optional `timeout` arg.
- **The auditor is the structural template** for the new agent: `a2a-agents/auditor/__main__.py` + `agent_executor.py`.
- **Existing attendee registration** (`companion/app.py:376-431`) registers MCP gateways pointing at `sales-tax`. We **replace** the attendee path with a local vote recorder. The `make salestax-*` / Stage-1-2 "Bob builds `add_tax`" beat is a separate code path and stays untouched.

## Decisions locked for this plan (veto on review)

1. **Crowd action = tap Approve or Reject** on the $50k wire (visceral and instant for non-coders), with optional initials for the wall. The **stance** concept (strict/lenient/random) belongs only to the 5 fixed agents, which is what produces a mixed *agent* tally.
2. **Finale = $50,000 Acme wire** (matches OPA's $10k cap money shot → deterministic BLOCK).
3. **5 fixed voters:** `room-strict-1`, `room-strict-2`, `room-lenient-1`, `room-lenient-2`, `room-random-1` — stance parsed from the name. On the $50k finale: the 2 strict reject, the 2 lenient approve, the random is a deterministic coin → a guaranteed mixed agent tally.
4. **Quorum renders in the standard scenario card** (`{verdict, headline, detail}`); no bespoke JS panel.
5. **Presenter controls:** a "Freeze voting" toggle and the existing reset path, so the room can't be vandalized mid-talk.

---

## File Structure

**Create:**
- `a2a-agents/room/vote.py` — pure voting + message parsing (no `a2a-sdk` import → unit-testable).
- `a2a-agents/room/test_vote.py` — pytest for the pure logic.
- `a2a-agents/room/agent_executor.py` — `RoomVoterExecutor` (thin a2a-sdk wrapper over `decide_vote`).
- `a2a-agents/room/__main__.py` — agent card + JSON-RPC routes + `/health`, uvicorn on `:8000`.
- `a2a-agents/room/Dockerfile` — mirrors `a2a-agents/auditor/Dockerfile`.
- `scripts/money-shots/quorum.sh` — headless proof: the 5 seeded voters produce a mixed tally and the $50k wire is BLOCKED.

**Modify:**
- `docker-compose.yml` — add the `room-agent` service.
- `gateway/seed/seed.py` — seed the 5 fixed `room-*` voters into `/a2a`.
- `companion/app.py` — `rpc()` timeout arg; local crowd state (`CROWD`, `CROWD_FROZEN`); `/api/vote`, `/api/crowd`, `/api/freeze`; `_room_agent_names()` / `_stance_of()`; `s_quorum()` + `SCENARIOS`; dashboard + wall template edits.
- `scripts/money-shots/run-all.sh` — call `quorum.sh` so `make verify-controls` covers it.
- `scripts/agents-reset.sh` — leave the 5 seeded `room-*` voters in place (they are re-seeded by `make seed`); clear nothing extra. (No per-attendee agents exist anymore.)
- `Makefile` — `verify-quorum` convenience target; add to `.PHONY`.
- `README.md` — one row documenting the quorum scenario.
- `docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md` — append the hybrid-architecture revision note.

---

## Task 0: ContextForge `/a2a` spike — GATES all implementation

This is a ~15-minute manual spike. **Do not write Tasks 1-9 until it passes**, because Tasks 4/6/8 all assume a seeded `room-*` agent yields a callable `a2a-room-*` tool that bridges a text message to a Python `a2a-sdk` agent. Codex correctly flagged these as unverified and load-bearing.

Run it against the *existing* mesh (no new code needed except a throwaway one-file agent, or reuse the auditor image), to prove the mechanics:

- [ ] **Step 1: Bring up the stack and mint an admin token**

```bash
make up && make seed
SECRET=${JWT_SECRET_KEY:-demo-only-change-me-0123456789abcdef}
TOKEN=$(DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- \
  python -m mcpgateway.utils.create_jwt_token -u admin@finbyte.demo --admin -e 10080 -s "$SECRET" 2>/dev/null | tail -1)
echo "${TOKEN:0:12}..."
```

- [ ] **Step 2: Register two A2A entries that share one backend via `?agent=`**

Point them at the already-running `auditor` backend (`http://auditor:9001/`) just to prove the catalog mechanics — uniqueness and tool creation — independent of the new image:

```bash
for n in spike-a spike-b; do
  curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -X POST localhost:4444/a2a \
    -d "{\"agent\":{\"name\":\"$n\",\"endpoint_url\":\"http://auditor:9001/?agent=$n\",\"agent_type\":\"jsonrpc\",\"description\":\"spike\",\"tags\":[\"spike\"]}}"
  echo
done
```

Record: did BOTH registrations return 2xx with only the query string differing? (Answers "is a unique `endpoint_url` required, and does `?agent=` satisfy it?")

- [ ] **Step 3: Confirm callable tools materialized, and time it**

```bash
for i in 1 2 3 4 5; do
  sleep 2
  echo "t=$((i*2))s: $(curl -s -H "Authorization: Bearer $TOKEN" localhost:4444/tools | python3 -c "import sys,json;print([t.get('name') for t in json.load(sys.stdin) if 'spike' in (t.get('name') or '')])")"
done
```

Record: the exact tool names (expect `a2a-spike-a` / `a2a-spike-b`) and how many seconds until they appear. This sets the seed→ready budget (must be well under demo start).

- [ ] **Step 4: Confirm the bridge delivers a text message to a Python a2a-sdk agent**

```bash
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -X POST localhost:4444/rpc \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"a2a-spike-a","arguments":{"message":{"role":"ROLE_USER","parts":[{"text":"Audit and pay $5000 to Corner Cafe approved"}],"messageId":"spike-1"}}}}' | head -c 600; echo
```

Record: did the auditor (a Python a2a-sdk agent, same SDK the room voter will use) receive the text and return a real artifact (not a tool-not-found / param error)? This is the single most important confirmation.

- [ ] **Step 5: Confirm delete removes the tool, then clean up**

```bash
for n in spike-a spike-b; do
  id=$(curl -s -H "Authorization: Bearer $TOKEN" localhost:4444/a2a | python3 -c "import sys,json;[print(a['id']) for a in json.load(sys.stdin) if a.get('name')=='$n']" | head -1)
  curl -s -H "Authorization: Bearer $TOKEN" -X DELETE "localhost:4444/a2a/$id"; echo " deleted $n ($id)"
done
```

- [ ] **Step 6: Decision gate**

- **If Steps 2-4 all pass:** proceed to Task 1. The seed budget from Step 3 informs nothing further (seeding happens at `make seed`, long before showtime).
- **If Step 4 fails** (the gateway bridges arguments to Python agents differently than the `message` envelope): STOP and report. Two recorded fallbacks: (a) the room voter also accepts a structured `{amount, stance, agent}` arguments form (add a branch in `RoomVoterExecutor` that reads `context` arguments directly); or (b) drop the bridged-call requirement and have the Companion call the room-agent backend **directly** (`http://localhost:9100/`) for the agent quorum, sacrificing the "through the gateway" governance line for the agent votes (the wire-block finale still proves governance). Bring this decision to the user — do not silently pick.

> Note the exact observed tool-name format and response shape in the commit message for Task 4/6 so the implementer uses the real strings.

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
    assert vote_expense(50000, "random", seed="room-random-1") == vote_expense(
        50000, "random", seed="room-random-1"
    )


def test_random_reaches_both_outcomes_across_seeds():
    outcomes = {vote_expense(50000, "random", seed=f"room-{i}")[0] for i in range(20)}
    assert outcomes == {"approve", "reject"}


def test_unknown_stance_falls_back_to_random():
    assert vote_expense(50000, "banana", seed="x") == vote_expense(
        50000, "random", seed="x"
    )


def test_decide_vote_strict_rejects_50k():
    out = decide_vote(
        "Vote on expense. payee=Acme LLC amount=50000 approval=false "
        "stance=strict agent=room-strict-1."
    )
    assert out.startswith("VOTE=reject ::")


def test_decide_vote_lenient_approves_50k():
    out = decide_vote("amount=50000 approval=false stance=lenient agent=room-lenient-1")
    assert out.startswith("VOTE=approve ::")


def test_decide_vote_defaults_to_random_when_stance_missing():
    out = decide_vote("amount=50000 agent=room-x")
    assert out.split(" ")[0] in ("VOTE=approve", "VOTE=reject")
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd a2a-agents/room && uv run --with pytest pytest test_vote.py -q
```
Expected: FAIL — `ModuleNotFoundError: No module named 'vote'`.

- [ ] **Step 3: Write the implementation**

Create `a2a-agents/room/vote.py`:

```python
"""Pure voting logic for the room A2A voter agents.

No network, no a2a-sdk import, so it unit-tests in isolation and is deterministic
on stage (no wall-clock / random entropy). agent_executor.py wraps decide_vote().
"""

import hashlib
import re

# Demo knobs (amount-driven so the agent tally is intuitive for a finance room).
STRICT_THRESHOLD = 10_000  # strict agents reject wires >= this (matches OPA cap)
LENIENT_THRESHOLD = 100_000  # lenient agents reject only the truly implausible


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

    digest = hashlib.sha256(f"{seed}:{amount:.0f}".encode()).hexdigest()
    if int(digest[:8], 16) % 2 == 0:
        return "approve", "random: coin landed approve"
    return "reject", "random: coin landed reject"


def parse_amount(text):
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
    """message text -> 'VOTE=<approve|reject> :: <reason>' (grep-friendly token)."""
    text = text or ""
    vote, reason = vote_expense(
        parse_amount(text), parse_stance(text), seed=parse_seed(text)
    )
    return f"VOTE={vote} :: {reason}"
```

- [ ] **Step 4: Run the tests to verify they pass**

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

Mirrors `a2a-agents/auditor/` in structure; only the skill body differs.

- [ ] **Step 1: Write the executor**

Create `a2a-agents/room/agent_executor.py`:

```python
"""Room voter agent executor.

Reads the vote prompt from the user message, computes a vote with the pure
decide_vote() logic, and returns it as a single text artifact. The stance and
expense travel inside the prompt, so this agent holds no per-voter state — one
process backs all five fixed catalog entries.
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
endpoint at '/', and a /health probe on 0.0.0.0:8000. ContextForge registers the
five fixed voter entries that all point here (distinguished by a ?agent= query
suffix that this server ignores), so they share one backend.
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
            "Votes approve/reject on an expense per a voting stance carried in "
            "the request (strict / lenient / random)."
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
        description="A governed voter in the expense-approval quorum.",
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

---

## Task 3: Containerize + add to the mesh

**Files:**
- Create: `a2a-agents/room/Dockerfile`
- Modify: `docker-compose.yml` (add `room-agent` after the `payments` service block, ~line 95)

- [ ] **Step 1: Write the Dockerfile**

Create `a2a-agents/room/Dockerfile` (mirrors auditor; no `httpx` — no outbound calls):

```dockerfile
FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir "a2a-sdk[http-server]==1.1.0" uvicorn

COPY . .

EXPOSE 8000

CMD ["python", "__main__.py"]
```

- [ ] **Step 2: Add the service to docker-compose.yml**

After the `payments` service block, add:

```yaml
  room-agent:
    build: ./a2a-agents/room
    ports:
      - "9100:8000"   # exposed for the A2A inspector + a host health probe
    restart: unless-stopped
```

- [ ] **Step 3: Build, run, and verify**

```bash
docker compose up -d --build room-agent
sleep 4
curl -s localhost:9100/health
curl -s localhost:9100/.well-known/agent-card.json | head -c 120
```
Expected: `{"status":"ok","server":"room-agent"}` and a card showing `"name":"Room Voter Agent"`.

- [ ] **Step 4: Commit**

```bash
git add a2a-agents/room/Dockerfile docker-compose.yml
git commit -m "feat(room-agent): containerize + add to the compose mesh"
```

---

## Task 4: Seed the 5 fixed voter agents

**Files:**
- Modify: `gateway/seed/seed.py` (after the A2A loop at lines 77-96)

- [ ] **Step 1: Add the fixed-voter constants near the `A2A` dict (after line 33)**

```python
# Fixed room voter agents for the quorum demo. Stance is encoded in the name and
# read back by the Companion; all share the one room-agent backend (the ?agent=
# query keeps each catalog URL unique). Seeded ONCE here so there is no live race.
ROOM_BACKEND = "http://room-agent:8000/"
ROOM_VOTERS = [
    "room-strict-1",
    "room-strict-2",
    "room-lenient-1",
    "room-lenient-2",
    "room-random-1",
]
```

- [ ] **Step 2: Register them after the existing A2A loop (after line 96, before the `time.sleep(3)` at line 99)**

```python
    # 2b) fixed room voter agents (quorum demo) -----------------------------
    existing_a = {a.get("name") for a in jget("/a2a")}
    for vname in ROOM_VOTERS:
        if vname in existing_a:
            print(f"[a2a] exists: {vname}")
            continue
        r = api(
            "POST",
            "/a2a",
            json={
                "agent": {
                    "name": vname,
                    "endpoint_url": f"{ROOM_BACKEND}?agent={vname}",
                    "agent_type": "jsonrpc",
                    "description": f"room voter ({vname})",
                    "tags": ["finbyte", "room"],
                }
            },
        )
        print(f"[a2a] register {vname}: {r.status_code} {r.text[:160]}")
```

- [ ] **Step 3: Verify seeding produces callable tools**

```bash
make seed
SECRET=${JWT_SECRET_KEY:-demo-only-change-me-0123456789abcdef}
TOKEN=$(DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- \
  python -m mcpgateway.utils.create_jwt_token -u admin@finbyte.demo --admin -e 10080 -s "$SECRET" 2>/dev/null | tail -1)
sleep 3
curl -s -H "Authorization: Bearer $TOKEN" localhost:4444/a2a | python3 -c "import sys,json;print(sorted(a['name'] for a in json.load(sys.stdin) if a.get('name','').startswith('room-')))"
curl -s -H "Authorization: Bearer $TOKEN" localhost:4444/rpc -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"a2a-room-strict-1","arguments":{"message":{"role":"ROLE_USER","parts":[{"text":"amount=50000 stance=strict agent=room-strict-1"}],"messageId":"seed-check"}}}}' | grep -o 'VOTE=[a-z]*'
```
Expected: the five `room-*` names listed, and the call returns `VOTE=reject` (use the real tool-name format recorded in Task 0 if it differs from `a2a-room-strict-1`).

- [ ] **Step 4: Commit**

```bash
git add gateway/seed/seed.py
git commit -m "feat(seed): register 5 fixed A2A room voters for the quorum demo"
```

---

## Task 5: Companion — local crowd voting

**Files:**
- Modify: `companion/app.py` — config block (replace lines 36-41), `rpc()` (55-66), room helpers (replace 333-373); replace `register_agent()` (376-431) and `agents()` (434-438) with crowd endpoints.

- [ ] **Step 1: Replace the config block (lines 36-41)**

```python
# ── crowd voting: attendees tap Approve/Reject on the $50k wire from their phones.
# Votes are recorded LOCALLY here (in-memory) — no gateway writes, no public catalog
# spam, cannot fail. The "real, governed agents" proof is the 5 fixed room-* voters
# seeded into /a2a (see gateway/seed/seed.py), called in the quorum scenario.
AGENT_PREFIX = "room"
CROWD = {}  # initials -> "approve" | "reject"  (one vote per initials, last wins)
CROWD_FROZEN = False
CROWD_CAP = 500  # hard cap on distinct voters held in memory
```

- [ ] **Step 2: Give `rpc()` a timeout argument (replace lines 55-66)**

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

- [ ] **Step 3: Replace the room helpers (lines 333-373) with fixed-voter helpers**

```python
# ── fixed A2A voter agents (seeded once into /a2a) ───────────────────────────
def _a2a_agents():
    try:
        a = httpx.get(f"{GW}/a2a", headers=H, timeout=10).json()
        return a if isinstance(a, list) else []
    except Exception:
        return []


def _room_agent_names(agents=None):
    """Names of the fixed room voter agents in the catalog (room-strict-1, ...)."""
    agents = _a2a_agents() if agents is None else agents
    return sorted(
        a.get("name", "")
        for a in agents
        if isinstance(a, dict) and a.get("name", "").startswith(AGENT_PREFIX + "-")
    )


def _stance_of(name):
    """Stance is encoded in the fixed voter's name."""
    for s in ("strict", "lenient", "random"):
        if s in name:
            return s
    return "random"


def _sanitize_initials(s):
    s = "".join(ch for ch in (s or "").upper() if ch.isalnum())[:5]
    return s or "ANON"
```

- [ ] **Step 4: Replace `register_agent()` and `agents()` (lines 376-438) with crowd endpoints**

```python
@app.route("/api/vote", methods=["GET", "POST"])
def vote():
    """Record one local crowd vote (approve/reject) on the $50k wire. No gateway
    writes — this cannot fail and cannot spam the catalog."""
    if CROWD_FROZEN:
        return jsonify({"ok": False, "error": "voting is frozen", "frozen": True}), 423
    initials = _sanitize_initials(
        request.values.get("initials") or request.values.get("ini")
    )
    choice = (request.values.get("choice") or "").strip().lower()
    if choice not in ("approve", "reject"):
        return jsonify({"ok": False, "error": "choice must be approve or reject"}), 400
    if initials not in CROWD and len(CROWD) >= CROWD_CAP:
        return jsonify({"ok": False, "error": "room is full"}), 429
    CROWD[initials] = choice
    approve = sum(1 for v in CROWD.values() if v == "approve")
    reject = len(CROWD) - approve
    return jsonify(
        {"ok": True, "initials": initials, "choice": choice,
         "approve": approve, "reject": reject, "count": len(CROWD)}
    )


@app.route("/api/crowd")
def crowd():
    approve = sum(1 for v in CROWD.values() if v == "approve")
    reject = len(CROWD) - approve
    recent = list(CROWD.keys())[-14:][::-1]
    return jsonify(
        {"approve": approve, "reject": reject, "count": len(CROWD),
         "frozen": CROWD_FROZEN, "recent": recent}
    )


@app.route("/api/freeze", methods=["POST"])
def freeze():
    """Presenter toggle: stop accepting crowd votes (so the room can't be gamed
    after the quorum runs). Idempotent; returns the new state."""
    global CROWD_FROZEN
    CROWD_FROZEN = (request.values.get("on", "1").strip().lower() not in ("0", "false", "off"))
    return jsonify({"ok": True, "frozen": CROWD_FROZEN})
```

- [ ] **Step 5: Verify the crowd endpoints (Companion running via `make companion`)**

```bash
curl -s -X POST "localhost:7070/api/vote?initials=MG&choice=approve" | python3 -m json.tool
curl -s -X POST "localhost:7070/api/vote?initials=AB&choice=reject" | python3 -m json.tool
curl -s localhost:7070/api/crowd | python3 -m json.tool
curl -s -X POST "localhost:7070/api/freeze?on=1" | python3 -m json.tool
curl -s -X POST "localhost:7070/api/vote?initials=ZZ&choice=approve" | python3 -m json.tool   # expect 423 frozen
```
Expected: votes accepted, tally `approve=1 reject=1 count=2`, freeze returns `frozen:true`, the post-freeze vote is rejected with 423.

- [ ] **Step 6: Commit**

```bash
git add companion/app.py
git commit -m "feat(companion): local crowd voting (vote/crowd/freeze), no catalog writes"
```

---

## Task 6: Companion — the quorum scenario (crowd + agents + OPA block)

**Files:**
- Modify: `companion/app.py` — add `import concurrent.futures`; add `s_quorum()` after `s_a2a` (~line 270); add the `quorum` entry to `SCENARIOS` (273-280).

- [ ] **Step 1: Add the import**

Alongside the existing stdlib imports at the top of `companion/app.py`:

```python
import concurrent.futures
```

- [ ] **Step 2: Add `s_quorum()` after `s_a2a` (after line 270)**

Note the `concurrent.futures.wait()` pattern — unlike `as_completed(timeout=...)`, `wait()` never raises on timeout, so a slow or dead agent cannot crash the live scenario.

```python
QUORUM_PAYEE = "Acme LLC"
QUORUM_AMOUNT = 50000  # OPA $10k cap -> BLOCKED without approval


def _vote_one(name):
    """Fan a vote prompt to one fixed room voter through the gateway; return its
    vote. Any gateway/transport error -> 'abstain' (never raises)."""
    stance = _stance_of(name)
    prompt = (
        f"Vote on expense. payee={QUORUM_PAYEE} amount={QUORUM_AMOUNT} "
        f"approval=false stance={stance} agent={name}."
    )
    resp = rpc(
        f"a2a-{name}",
        {"message": {"role": "ROLE_USER", "parts": [{"text": prompt}],
                     "messageId": f"q-{name}"}},
        timeout=8,
    )
    blob = json.dumps(resp)
    vote = "approve" if "VOTE=approve" in blob else ("reject" if "VOTE=reject" in blob else "abstain")
    return {"agent": name, "stance": stance, "vote": vote}


def s_quorum():
    # 1) crowd (local, instant, cannot fail)
    crowd_approve = sum(1 for v in CROWD.values() if v == "approve")
    crowd_reject = len(CROWD) - crowd_approve

    # 2) agent quorum (real, governed) — the 5 fixed seeded voters
    names = _room_agent_names()
    votes = []
    if names:
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, len(names))) as pool:
            futs = {pool.submit(_vote_one, n): n for n in names}
            done, not_done = concurrent.futures.wait(futs, timeout=15)
            for f in done:
                try:
                    votes.append(f.result())
                except Exception:
                    n = futs[f]
                    votes.append({"agent": n, "stance": _stance_of(n), "vote": "abstain"})
            for f in not_done:
                f.cancel()
                n = futs[f]
                votes.append({"agent": n, "stance": _stance_of(n), "vote": "abstain"})
    votes.sort(key=lambda v: v["agent"])
    a_app = sum(1 for v in votes if v["vote"] == "approve")
    a_rej = sum(1 for v in votes if v["vote"] == "reject")
    a_abs = sum(1 for v in votes if v["vote"] == "abstain")

    # 3) the payoff: attempt the wire. OPA blocks it at the $10k cap regardless.
    wire_name = "erp-payments-wire"
    wire_args = {"payee": QUORUM_PAYEE, "amount": QUORUM_AMOUNT, "approval": False}
    wire = rpc(wire_name, wire_args)
    wtext, werr = text_of(wire)
    blocked = "Plugin Violation" in json.dumps(wire)

    agent_lines = [f"  {v['agent']:<16} {v['stance']:<8} → {v['vote']}" for v in votes]
    detail = (
        f"ROOM (phones): approve={crowd_approve}  reject={crowd_reject}  "
        f"(of {len(CROWD)} voters)\n\n"
        f"GOVERNED A2A AGENTS (through the gateway):\n"
        + ("\n".join(agent_lines) if agent_lines else "  (no voter agents seeded — run `make seed`)")
        + f"\n  agent tally: approve={a_app} reject={a_rej} abstain={a_abs}\n\n"
        + (
            f"  ${QUORUM_AMOUNT:,} wire attempted anyway → {werr or wtext}"
            if blocked
            else f"  wire result → {wtext or werr}"
        )
    )
    return dict(
        verdict="BLOCKED" if blocked else "SEE RAW",
        blocked=blocked,
        headline=(
            f"Room {crowd_approve}-{crowd_reject}, agents {a_app}-{a_rej} — OPA blocked "
            f"the ${QUORUM_AMOUNT:,} wire anyway (policy beats consensus)"
        ),
        detail=detail,
        raw=wire,
        request={"name": wire_name, "arguments": wire_args},
    )
```

- [ ] **Step 3: Register the scenario in `SCENARIOS` (lines 273-280)**

Add as the last entry:

```python
    "quorum": ("Expense approval quorum — policy beats consensus", s_quorum),
```

- [ ] **Step 4: Verify the scenario end-to-end**

With the stack up + seeded and `make companion` running, cast a couple of crowd votes (Task 5 curls), then:
```bash
curl -s localhost:7070/api/run/quorum | python3 -m json.tool
```
Expected: `"verdict": "BLOCKED"`, `"blocked": true`, a `detail` showing the room tally, the 5 agent votes (mixed: strict→reject, lenient→approve, random→one or the other), and the blocked wire line.

- [ ] **Step 5: Commit**

```bash
git add companion/app.py
git commit -m "feat(companion): quorum scenario — crowd + governed agent votes, OPA blocks the wire"
```

---

## Task 7: Companion UI — vote buttons, freeze, quorum card

**Files:**
- Modify: `companion/app.py` — `SCEN` array (790-792), the `.roombar` form (775-779), the JS `registerAgent`/`pollAgents` (856-876), and the `WALL` template (880-916).

- [ ] **Step 1: Add the quorum card to `SCEN` (lines 790-792)**

Append after the `a2a` entry:

```javascript
 ["quorum","Expense approval quorum — policy beats consensus"]];
```
(So the array's final line becomes the `injection`/`a2a` entries followed by this `quorum` entry — keep the existing entries unchanged.)

- [ ] **Step 2: Replace the `.roombar` register form (lines 773-783) with crowd vote controls**

```html
   <div class="roombar">
     <div class="roomcount">🗳️ Room vote on the $50k wire — ✅ <b id="crowdA">0</b> approve · ⛔ <b id="crowdR">0</b> reject <span id="crowdUp"></span></div>
     <div class="roomreg">
       <input id="ini" maxlength="5" placeholder="your initials" autocapitalize="characters">
       <button onclick="castVote('approve')">✅ Approve</button>
       <button onclick="castVote('reject')" style="background:var(--block)">⛔ Reject</button>
       <button class="ev" onclick="toggleFreeze()" id="freezeBtn">🔒 Freeze</button>
       <span id="regout" class="small"></span>
     </div>
     <a class="wall-link qr-link" href="/qr" target="_blank">📲 Join QR</a>
     <a class="wall-link" href="/wall" target="_blank">📺 Open wall</a>
     <!--CONNECT_LINK-->
   </div>
```

- [ ] **Step 3: Replace `registerAgent()` + `pollAgents()` (lines 856-876) with crowd JS**

```javascript
let frozen=false;
async function castVote(choice){
 const ini=document.getElementById('ini').value;
 const out=document.getElementById('regout'); out.textContent='voting…';
 try{
   const r=await (await fetch('/api/vote?initials='+encodeURIComponent(ini)+'&choice='+choice,{method:'POST'})).json();
   if(r.ok){out.textContent='✓ '+r.initials+' voted '+r.choice; document.getElementById('ini').value=''; pollCrowd();}
   else out.textContent='⚠ '+(r.error||'failed');
 }catch(e){out.textContent='⚠ '+e;}
}
async function toggleFreeze(){
 frozen=!frozen;
 try{
   const r=await (await fetch('/api/freeze?on='+(frozen?1:0),{method:'POST'})).json();
   document.getElementById('freezeBtn').textContent = r.frozen ? '🔓 Unfreeze' : '🔒 Freeze';
 }catch(e){}
}
let lastN=null;
async function pollCrowd(){
 try{
   const a=await (await fetch('/api/crowd')).json();
   document.getElementById('crowdA').textContent=a.approve;
   document.getElementById('crowdR').textContent=a.reject;
   if(lastN!==null && a.count>lastN){const u=document.getElementById('crowdUp'); if(u){u.textContent='↑'; setTimeout(()=>u.textContent='',1000);}}
   lastN=a.count;
   document.getElementById('freezeBtn').textContent = a.frozen ? '🔓 Unfreeze' : '🔒 Freeze';
 }catch(e){}
}
```

- [ ] **Step 4: Fix the startup calls (lines 874-876)**

Replace the trailing `loadState(); pollAgents(); setInterval(pollAgents, 3000);` with:

```javascript
loadState();
pollCrowd();
setInterval(pollCrowd, 2000);
```

- [ ] **Step 5: Point the WALL at the crowd tally (lines 880-916)**

In the `WALL` template, change the data source from `/api/agents` to `/api/crowd` and show the approve/reject split. Replace the `tick()` function body (around lines 905-913) with:

```javascript
 async function tick(){
  try{
   const a=await (await fetch('/api/crowd')).json();
   const n=document.getElementById('n');
   if(last!==null && a.count>last){n.classList.add('bump'); setTimeout(()=>n.classList.remove('bump'),260);}
   n.textContent=a.count; last=a.count;
   const c=document.getElementById('chips');
   c.innerHTML=(a.recent||[]).map((x,i)=>`<span class="chip${i===0?' fresh':''}">${(x+'').replace(/[<>&]/g,'')}</span>`).join('');
  }catch(e){}
 }
```

And update the wall label text (line 900) from "agents built by the room — registered with the control plane, live" to:

```html
 <div class="label">votes cast by the room on the $50,000 wire — live</div>
```

- [ ] **Step 6: Verify in the browser**

With `make companion` running, open `http://localhost:7070`:
- The room bar shows live Approve/Reject counts and the two vote buttons.
- Voting with initials moves the counts; `/wall` mirrors them.
- "Freeze" flips to "Unfreeze" and blocks further votes (button + 423 from the API).
- The "Expense approval quorum" card runs to a BLOCKED verdict showing both tallies.

- [ ] **Step 7: Commit**

```bash
git add companion/app.py
git commit -m "feat(companion): crowd vote buttons + freeze + quorum card in the dashboard"
```

---

## Task 8: Headless proof + Make wiring

**Files:**
- Create: `scripts/money-shots/quorum.sh`
- Modify: `scripts/money-shots/run-all.sh`, `Makefile`

The 5 voters are seeded by `make seed`, so the proof needs no registration/cleanup — it just asserts the seeded agents vote correctly and the wire is blocked.

- [ ] **Step 1: Write the proof**

Create `scripts/money-shots/quorum.sh`:

```bash
#!/usr/bin/env bash
# Headless proof of the A2A quorum: the seeded fixed voters disagree (strict
# rejects, lenient approves) and OPA blocks the $50k wire regardless. Assumes
# `make seed` has registered the room-* voters. Usage: bash scripts/money-shots/quorum.sh
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

vote(){ # toolname, stance, agentname -> echoes the response
  curl -s "${AUTH[@]}" -X POST "$GW/rpc" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":{\"message\":{\"role\":\"ROLE_USER\",\"parts\":[{\"text\":\"amount=50000 approval=false stance=$2 agent=$3\"}],\"messageId\":\"qt-$3\"}}}}"
}

echo "== A2A quorum: seeded voters disagree, OPA still blocks =="
rs=$(vote a2a-room-strict-1 strict room-strict-1)
rl=$(vote a2a-room-lenient-1 lenient room-lenient-1)
printf '%s' "$rs" | grep -q "VOTE=reject"  && ok "strict voter REJECTS the \$50k wire" || no "strict should reject (got: $(printf '%s' "$rs" | head -c 120))"
printf '%s' "$rl" | grep -q "VOTE=approve" && ok "lenient voter APPROVES the \$50k wire" || no "lenient should approve (got: $(printf '%s' "$rl" | head -c 120))"

w=$(curl -s "${AUTH[@]}" -X POST "$GW/rpc" -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"erp-payments-wire","arguments":{"payee":"Acme LLC","amount":50000,"approval":false}}}')
printf '%s' "$w" | grep -qF "Plugin Violation" && ok "\$50k wire BLOCKED despite the votes (policy beats consensus)" || no "wire should be blocked (got: $(printf '%s' "$w" | head -c 120))"

echo "  ── quorum: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] || exit 1
```

```bash
chmod +x scripts/money-shots/quorum.sh
```

- [ ] **Step 2: Run it (stack up + seeded + room-agent built)**

```bash
make up && make seed
docker compose up -d --build room-agent
bash scripts/money-shots/quorum.sh
```
Expected: `quorum: 3 passed, 0 failed`. (Use the real `a2a-room-*` tool-name format from Task 0 if it differs.)

- [ ] **Step 3: Wire into `make verify-controls`**

In `scripts/money-shots/run-all.sh`, just before the final `RESULT` echo block, add:

```bash
echo "== A2A quorum (policy beats consensus) =="
if bash "$(dirname "$0")/quorum.sh"; then PASS=$((PASS+3)); else FAIL=$((FAIL+1)); fi
```

- [ ] **Step 4: Add a `verify-quorum` convenience target**

In the `Makefile`, after `verify-controls` (line 447), add:

```makefile
verify-quorum: ## Prove just the A2A quorum (uses the seeded room-* voters)
	@bash scripts/money-shots/quorum.sh
```

Add `verify-quorum` to the `.PHONY` line (line 34).

- [ ] **Step 5: Commit**

```bash
git add scripts/money-shots/quorum.sh scripts/money-shots/run-all.sh Makefile
git commit -m "test(quorum): headless proof + verify-controls/Make wiring"
```

---

## Task 9: Docs — README row + spec revision

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md`

- [ ] **Step 1: Document the scenario in the README**

In `README.md`, near the scenarios/controls list (around line 44), add:

```markdown
- **Expense approval quorum** — the room votes on a $50k wire from their phones (live local tally) while 5 governed A2A voter agents vote through the ContextForge gateway (each call authn'd + audited). OPA then blocks the wire regardless of either tally. **Policy beats consensus.**
```

- [ ] **Step 2: Append the hybrid revision to the spec**

In `docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md`, append:

```markdown
## Architecture revision (post-Codex review)

Pivoted from per-attendee A2A registration to a hybrid model after an independent review flagged the per-phone catalog write on a public tunnel as the main live-demo risk:

- **Crowd votes are local** to the Companion (in-memory Approve/Reject), so attendee taps never write to `/a2a`. Removes tool-materialization races, fan-out latency at scale, and public catalog spam.
- **The governed-agent proof is a fixed set of 5 `room-*` voters** seeded once at `make seed` (stance encoded in the name: strict/lenient/random). The quorum fans a vote to those 5 through `/rpc` — real, authn'd, audited.
- **Finale unchanged:** the $50k Acme wire is attempted and OPA denies it at the $10k cap.
- **Quorum fan-out uses `concurrent.futures.wait()`** (not `as_completed(timeout=...)`, which raises on timeout and could crash the live scenario).
- **Presenter controls:** a Freeze toggle on crowd voting; a `CROWD_CAP` on distinct voters.
- Stances are amount-driven: strict rejects ≥ $10k, lenient approves up to $100k, random is a deterministic per-agent coin.
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/superpowers/specs/2026-06-24-a2a-quorum-demo-design.md
git commit -m "docs: document the hybrid A2A quorum + reconcile spec"
```

---

## Final verification (after all tasks)

- [ ] **Spike passed** (Task 0) before any implementation began.
- [ ] **Unit logic:** `cd a2a-agents/room && uv run --with pytest pytest test_vote.py -q` → all green.
- [ ] **Full headless gate:** `make up && make seed && docker compose up -d --build room-agent && make verify-controls` → `RESULT: 19 passed, 0 failed` (16 original + 3 quorum).
- [ ] **Live demo:** `make companion`, open `:7070`; cast a few crowd votes (and from a phone via the QR); Run the quorum card → BLOCKED with both tallies; the wall climbs; Freeze stops new votes.
- [ ] **Repeatable:** `make demo-reset` reseeds the 5 voters; the crowd tally resets on Companion restart (expected — it is ephemeral by design).

---

## Self-Review

**Spec coverage:** Hybrid spec maps to tasks — room-agent backend (T1-T3), 5 fixed governed voters (T4), local crowd voting + freeze + cap (T5), quorum fan-out through the gateway + OPA block (T6), UI (T7), headless proof (T8), docs (T9). The ContextForge assumptions the spec/Codex flagged are de-risked by the gating spike (T0). The spec's optional OPA source-agent stamp remains out of scope.

**Placeholder scan:** No TBD/TODO; every code step is complete and runnable. The only conditional guidance (Task 0 fallback, real tool-name format) is explicit verification branching with named alternatives, not missing code.

**Type/name consistency:** Fixed voter names `room-<stance>-N` → tools `a2a-room-<stance>-N` → parsed by `_stance_of()` and `_room_agent_names()` (prefix `room-`). `decide_vote` returns `VOTE=<vote> ::`, consumed identically by `_vote_one` (T6) and `quorum.sh` (T8). `vote_expense(amount, stance, seed)` matches across `vote.py`, `test_vote.py`, `decide_vote`. Crowd state (`CROWD`, `CROWD_FROZEN`, `CROWD_CAP`) is consistent across `/api/vote`, `/api/crowd`, `/api/freeze`, and `s_quorum`. Finale tool `erp-payments-wire` + marker `Plugin Violation` match `s_policy` and the existing money shot. The `concurrent.futures.wait()` pattern replaces the crash-prone `as_completed(timeout=...)` Codex flagged.
