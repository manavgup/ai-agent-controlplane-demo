# Progressive-build artifact continuity — design

**Issue:** [#9](https://github.com/manavgup/ai-agent-controlplane-demo/issues/9) — *Tighten the progressive-build showcase: carry the Bob-built server through Stages 1→2 + dev-focus the build page*
**Follow-up to:** PR #8 (merged, `c92095c`)
**Date:** 2026-06-13

## Problem

The Dev Day progressive-build track (`make stage1-build … stage4-mesh`, surfaced on
`docs/cockpit.html` → 🎓 Progressive Build) silently **swaps artifacts** mid-story:

- **Stage 1** — Bob builds `sales-tax` from scratch, runs it bare on `:8000`.
- **Stage 2** — onboards `fx-rates`, a *different* pre-existing service.
- **Stage 3** — controls fire on the expense/payments mesh (yet another set).

So the thing the developer *built* is abandoned after Stage 1 — never governed,
never used again. It reads as three disconnected demos instead of one artifact
carried build → run → govern → use. Secondary gaps: the "dev" is under-shown (only
the prompt is visible, not Bob's code, its iterate loop, or the tool actually
running), the killer "drive it from your laptop with just Bob" message lives only
in `docs/ONBOARDING.md`, and the build-page copy is presenter-framed ("the room",
"the gasp", "live-talk path") rather than dev-voiced.

## Goals

1. **Carry one artifact end-to-end.** The `sales-tax` server Bob writes in Stage 1
   is containerized and governed in Stage 2 — the payoff for building it.
2. **Keep the "extend an existing service" teaching point** as a co-equal beat:
   Bob adds a `convert` tool to `fx-rates`, re-onboards, and calls it.
3. **Show the dev.** Bob's generated code, its write→run→fix loop, and the tool
   actually returning a value.
4. **Surface BYOB on the build page** — "No Docker? drive the mesh with just Bob."
5. **Dev-voice the framing.**
6. **Never break `make up` on a fresh clone** (no `server.py` yet).

## Non-goals

No changes to the four controls, OPA policies, the A2A agents, or the Cockpit view
(beyond a note that its `<h1>` is shared). No renumbering of the four top-level
stages. No new onboarding tiers (those shipped in #8).

## Decisions (resolved during brainstorming)

| # | Decision | Rationale |
|---|---|---|
| D1 | **Containerize sales-tax, then govern it** (vs. governing the bare host process via `host.docker.internal`). | Fully internal compose-network DNS sidesteps the container→host networking gotcha — robust on Mac/Linux/Codespaces (multi-arch constraint). Mirrors the proven `fx-rates` path. True-to-life "package to deploy" beat. |
| D2 | **fx-rates becomes a co-equal Stage 2b beat** — Bob *adds a `convert` tool* (true "extend"), not just registers it as-is. | Keeps build-from-scratch AND extend-existing both first-class, per issue. |
| D3 | **Four top-level stages, 2a/2b as sub-beats.** | Preserves the `stage1…stage4` targets and the build→govern→control→mesh mental model. |
| D4 | **Deterministic `add_tax(100)` call is the primary Stage-1 proof**; the MCP Inspector demotes to optional. | "It works — and that's the problem" lands faster than the Inspector "Via Proxy → Connect" dance. |
| D5 | **2b edits the tracked `fx-rates/server.py` live**, reverted by `reset` via `git checkout`; `server_with_convert.py` is the fallback source. | The edit *is* the "extend" beat; git restores a clean tree. |
| D6 | **"No Docker? just Bob" twisty near the top** of the build view (after *Architecture at a glance*). | People who can't run the stack should see the alternative immediately. |

## The narrative spine

| Stage | What the dev does | Artifact |
|---|---|---|
| **1 — Build** | Bob writes `sales-tax` from scratch → runs it **bare** on `:8000` → **calls it** (`add_tax(100) → 108.50`, no token, no policy) | `sales-tax` (yours) |
| **2 — Govern** | **2a:** containerize that same `server.py` → onboard at `http://sales-tax:8000/mcp` (token-gated). **2b:** Bob *extends* `fx-rates` — adds `convert` → rebuild → re-onboard → `convert 1000 USD→EUR` | `sales-tax` carried + `fx-rates` extended |
| **3 — Control** | The four controls bite real calls (PII redaction, injection, OPA wire-block, RBAC) | the governed mesh |
| **4 — Mesh** | Full picture (== `quickstart` end-state); pick a cockpit | everything |

Stage 2a is the payoff for Stage 1; Stage 2b is the "Bob can also extend services
you didn't write" flex.

## Components

### New files (both committed; neither gitignored)

**`mcp-servers/sales-tax/Dockerfile`** — byte-for-byte the `fx-rates` pattern:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir fastmcp==3.3.1
COPY server.py .
EXPOSE 8000
CMD ["python", "server.py"]
```

Multi-arch base, no pinned digest. It `COPY`s the *generated* `server.py`, so it
only ever builds at Stage 2 — after Bob (or the scaffold) has written the file.

**`docker-compose.salestax.yml`** — a stage-2-only override joining the base
project network:

```yaml
services:
  sales-tax:
    build: ./mcp-servers/sales-tax
    restart: unless-stopped
```

The base `make up` never references this file, so a fresh-clone `make up` cannot
trip over the missing `server.py`.

### New Makefile targets

(Compose-engine selection stays in the Makefile where `$(COMPOSE)` resolves
docker vs. podman.)

- `salestax-up` — `$(COMPOSE) -f docker-compose.yml -f docker-compose.salestax.yml up -d --build sales-tax`. Guarded: clear error if `mcp-servers/sales-tax/server.py` is absent.
- `salestax-down` — stop & remove just the `sales-tax` container (used by `reset`/`clean`).
- `salestax-register` — deterministic fallback for the 2a onboard (mirrors `fxrates-register`).
- `fxrates-extend` — deterministic fallback for 2b: copy `server_with_convert.py` → `server.py`, `$(COMPOSE) up -d --build fx-rates`, re-register.

### `scripts/stages.sh` — `stage_govern` rewrite (replaces lines 116–146)

1. **Guard:** if `mcp-servers/sales-tax/server.py` is absent → print "run `make stage1-build` or `make stage1-scaffold` first" and exit. You cannot govern what wasn't built.
2. `make up` + `make seed` + operator persona (unchanged).
3. **2a:** `make salestax-up` (build + run the sales-tax container on the mesh network) → `stop_raw` *after* it's healthy (the container takes over from the bare host process) → Bob registers `http://sales-tax:8000/mcp`. Fallback `make salestax-register`. Payoff line: the tool you ran wide-open 60 seconds ago is now token-gated behind the one seam.
4. **2b:** Bob adds a `convert(amount, src_ccy, dst_ccy)` tool to `mcp-servers/fx-rates/server.py` (avoid `from`/`to` — `from` is a Python reserved word; match whatever `server_with_convert.py` already uses so the fallback stays consistent) → `$(COMPOSE) up -d --build fx-rates` → re-onboard → `convert 1000 USD→EUR`. Fallback `make fxrates-extend`.

### `scripts/stages.sh` — Stage-1 proof-of-life (`stage_build`)

After the bare server is healthy and **before** the optional Inspector, run a
deterministic tool call — a tiny `uv run --with fastmcp==3.3.1` client that calls
`add_tax(100)` and prints:

```
add_tax(100, 8.5) → tax=8.50, total=108.50   (no token, no policy — anyone on :8000 can call this)
```

The Inspector launch (currently the foreground blocker) moves behind an optional
prompt so the proof-of-life is the primary beat.

### `scripts/stages.sh` — `reset`

Extend to: `stop_raw`; remove generated `sales-tax/server.py`; `make salestax-down`;
`git checkout -- mcp-servers/fx-rates/server.py` (undo the 2b live edit). Leaves
`_solution.py` and `server_with_convert.py` (tracked fallbacks) in place.

### `docs/cockpit.html` — build view

- **Headline** (l.209) → "Build an MCP server in 2 minutes — then watch it get governed."
- **Lede** (l.210) → second-person; add the "containerize it" beat.
- **De-presenter copy:** "stalls the room" → "if a live edit wobbles"; "live-talk path" (l.211) → "all-at-once path is `make quickstart`"; Stage 3 pill "the gasp" (l.255) → "4 controls fire"; Stage 4 "the room watched it get built" (l.280) → "you built it stage by stage." Shared `<h1>` (l.176) left unchanged.
- **Stage 1:** add a collapsed **"What Bob produced"** twisty (the ~15-line `server.py` snippet from `_solution.py`); an agentic-loop line ("Bob writes, runs, and fixes its own code — paste the error back and it iterates"); the `add_tax(100) → 108.50` proof-of-life as step ②, Inspector demoted to a nested "Want to poke it by hand?" twisty.
- **Stage 2:** rewrite l.239–252 into **2a** (containerize + onboard `sales-tax`, fallback `make salestax-register`) and **2b** ("Bonus — Bob extends an existing service": add `convert` to `fx-rates`, fallback `make fxrates-extend`).
- **New twisty near the top** (after *Architecture at a glance*): **"No Docker on your laptop? Drive the whole mesh with just Bob"** → `make connect` + the Codespaces BYOB flow (`-t http` + `/mcp`), verified in #8.
- **Reset twisty** (l.291–298): keep `stage-reset`/`demo-reset`/`fxrates-reset` accurate to the new `reset` behavior.

## Testing

### Fresh-clone safety (must-not-break invariant)

- With **no** `mcp-servers/sales-tax/server.py`, `make up && make seed` brings up the
  full 10-service mesh green (base compose never references the override).
- `mcp-servers/sales-tax/server.py` remains uncommitted but **not** gitignored.
- CI `ci` aggregate (lint, bandit, compose-validate) passes; `compose-validate` runs
  against the base file only and must not choke on the override.

### Stage-flow self-test (local, pre-Codespaces)

1. `make stage-reset` → clean slate (no `server.py`).
2. `make stage1-scaffold` (stands in for Bob) → `make stage1-build` → confirm bare
   server + the `add_tax(100) → 108.50` proof-of-life.
3. `make stage2-govern` → confirm the sales-tax **container** builds, lands in the
   catalog at `http://sales-tax:8000/mcp`, **and** the 2b `convert` beat works.
4. `make stage3-controls` → `make verify-controls` → **16/16**.
5. `make stage-reset` + `make fxrates-reset` → `git status` clean (2b edit reverted,
   generated files gone).

### Codespaces re-test (required — item #1 changes behavior)

Re-run the BYOB proof from a Codespace: stack up, port 4444 Public, `make connect`,
then a laptop Bob (`-t http` + `/mcp`) registers and **calls the governed `sales-tax`
tool**. Same proof that passed in #8, now exercising the new artifact path. Run by
the author (needs their Codespace); an exact checklist will accompany the plan.

## Risks

- **2b live edit dirties the tree** — mitigated by `reset`'s `git checkout`; the
  fallback `fxrates-extend` is idempotent.
- **Stage-2 container build adds a few seconds live** — acceptable; the `salestax-up`
  guard + scaffold fallback keep it from stranding the talk.
- **Override-file network join** — must share the base project name so DNS `sales-tax`
  resolves from the gateway; verified in the stage-flow self-test.
