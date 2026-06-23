# Dev Day — 50-minute stage runsheet

**Story:** *Build an agent tool with Bob → put ContextForge in charge of it →
watch the controls bite.* Bob is the star; the `make` commands are just scene
changes. The audience never sees a JWT or a UUID — those are backstage.

**Arc:** ① Build (Bob) → ② Govern your own tool (Bob) → ③ The four controls (Bob).

---

## 🚀 Fire up ContextForge from Codespaces (the thing I keep forgetting)

The whole governed mesh runs in the cloud; the devcontainer does the work for you.

1. GitHub → this repo → green **Code** button → **Codespaces** tab → **Create codespace on main**.
   (Or the **Open in Codespaces** badge in the README.)
2. Wait a few minutes. `.devcontainer/post-create.sh` auto-runs **`make up && make seed`** —
   that *is* ContextForge: the gateway on port **4444** + the full mesh, seeded. You'll see a
   **"READY"** banner in the terminal when it's done.
3. **If you reopened an existing Codespace** (post-create only runs the first time) or the banner
   didn't appear, just run it yourself in the Codespace terminal:
   ```bash
   make up && make seed
   ```
4. **PORTS** tab → set **both** ports **Public** (right-click → Port Visibility → Public):
   **4444** (the gateway) **and 7070** (the Companion). Both are needed for a room — phones hit
   `:7070`, and Tier-2 laptops download their connect config from `:7070/bob/settings.json`.
5. Start the Companion with the connect page on: **`make companion-connect`** (= `EXPOSE_CONNECT=1 make companion`).
   This serves the Tier-1 dashboard **and** the Tier-2 **🔌 Connect Bob** page (copy/download — no token typing).
6. `make follow-link` → prints the `follow.html?dash=<:7070 url>` link to share/QR (lights up **▶ Run it live**).
7. `make connect` (optional) → the presenter-terminal `bob mcp add … -t http …/mcp` line. Attendees normally
   self-serve from the Connect Bob page instead, so this is mainly your own backup.
8. Sanity check: open **`:4444/admin`** (`admin@finbyte.demo` / `FinByteAdmin!2026`) — the
   ContextForge admin UI listing every server/tool/agent. (Forwarded ports are private by default;
   the admin UI works in-Codespace without flipping visibility.)

> ⚠️ Use the `-t http` + `/mcp` form `make connect` prints — **never SSE** (Codespaces proxies
> buffer SSE and Bob hangs). Paste it **from an empty folder** (a repo clone's `.bob/mcp.json`
> shadows it). Tear the Codespace/port down after — `make connect` embeds an admin token.

## 👀 Audience follow-along (non-coders, no GitHub)

Put the QR (`docs/assets/follow-qr.png`) on a slide → it opens **`follow.html`**: a plain-English,
tap-along "YOU ARE HERE" stage tracker, plus a **"How do you want to take part?"** chooser with three
tiers. `build.html` stays the deeper, coder version for the technical crowd.

- **Tier 1 — Follow along + run it** (browser only, phone or laptop, no install): watch the stages
  **and run the scenarios** on the shared Companion dashboard. With `make companion-connect` running and
  **7070 Public** (steps 4–5 above), `make follow-link` prints the `follow.html?dash=<:7070 url>` link to
  share (QR it). That lights up the page's **▶ Run it live** button.
- **Tier 2 — Drive Bob yourself** (laptop + IBM Bob, no Docker): attendees **don't type the token**.
  Run the companion with `EXPOSE_CONNECT=1 make companion` (a.k.a. `make companion-connect`), share the
  dashboard link, and they click **🔌 Connect Bob (laptop)** → **Copy command** or **Download settings.json**
  (or the one fixed `curl … /bob/settings.json` line). `make connect` still works as the presenter-terminal path.
- **Tier 3 — Do it all yourself** (Docker + Bob): `make quickstart` on their own machine.

### 🛠️ Audience participation — build the room's agents

During the Build/Govern beat, invite everyone to **name an agent with their initials and register it**:
- **Phones (Tier 1):** on the Companion dashboard, type initials → **Register my agent ▶** (no install) —
  it really registers `salestax-<INITIALS>` with ContextForge.
- **Bob drivers (Tier 2/3):** connect to the **Operator** persona (`make connect` / `make bob-operator`), then:
  *"Register an MCP server named `salestax-<YOUR-INITIALS>` at http://sales-tax:8000/mcp?agent=<YOUR-INITIALS>."*
  (The `?agent=` suffix keeps each URL unique — ContextForge requires it; the backend ignores the query.)
  Tier 2 registers against the **shared** cloud gateway → lands on the same wall; Tier 3 registers on their **own** gateway.
- **Watch it climb:** project the Companion's `/wall` (giant count + initials landing live). Each registration
  is a real catalog entry; names dedup + retry so repeats still bump the count.
- **Before each session:** `make agents-reset` (also folded into `make demo-reset`) clears `salestax-*` → back to 0.
- Requires the `sales-tax` backend up (Stage ②); the Companion's `AGENT_BACKEND_URL` is configurable for testing.

### Where the single control plane runs (how the whole room connects)

One Docker Compose stack on **one host** (a GitHub Codespace is the recommended single instance — the
devcontainer runs `make up && make seed`; you add `make companion-connect`). Only **two ports** are exposed:

```
   ┌──────────────── ONE HOST (a GitHub Codespace) ─────────────┐
   │   :7070  Companion ──┐                                     │
   │   (holds token,      ├──► :4444 Gateway ──► OPA            │
   │    calls gateway)    │    (ContextForge)    6 MCP servers  │
   │                      │                      2 A2A agents   │
   └──────────┼───────────┴────────────────────────────────────┘
        PUBLIC :7070                 PUBLIC :4444
              │                            │
   ┌──────────┴───┐          ┌─────────────┴┐          ┌─────────────────┐
   │ TIER 1       │          │ TIER 2       │          │ TIER 3          │
   │ browser      │          │ laptop + Bob │          │ their OWN stack │
   │ phone/laptop │          │ (no Docker)  │          │ make quickstart │
   └──────────────┘          └──────────────┘          └─────────────────┘
   ── all hit the SAME instance ──►              ◄── separate, per person
```

- **Tier 1** → the public **:7070** Companion (it calls :4444 server-side, so phones need nothing).
- **Tier 2** → the public **:4444** gateway directly, via `bob mcp add`.
- **Tier 3** is the exception — their own local stack, not the shared instance.

**Caveats:** one instance = one gateway DB + one OPA. Read/block/allow control scenarios are safe for a
whole room at once; *mutating* operator beats (register-a-server, reset) collide — keep those
presenter-driven or send power users to Tier 3. For a big room hammering "Run all," size the Codespace
up (4-core/16GB); Tiers 1+2 share that one box.

---

## PRE-STAGE — do this OFF-stage, before the room (≈10 min)

This pre-bakes everything fragile so the only *live* thing on stage is Bob talking.

```bash
make clean                 # fresh .bob state (clears stale persona configs)
bob                        # sign in via SSO in the browser, confirm prompt, then /quit
make quickstart            # full governed mesh up + seeded + verified 16/16 (the controls)
make stage-reset           # remove any sales-tax server.py so the BUILD is fresh on stage
```

Confirm before you walk on:
- [ ] `make verify-controls` → **16 passed, 0 failed**
- [ ] Admin UI loads at `localhost:4444` → `admin@finbyte.demo` / `FinByteAdmin!2026` (no password wall — fixed in `.env`)
- [ ] `bob` launches authenticated (token budget shows bottom-bar)
- [ ] Two terminals + browser on the monitor; font size up

> Why pre-stage: every failure we hit in dry-run (SSO hang, stale config, broken
> 2nd build, reseed UUID churn) lives in the *setup*. Doing setup off-stage removes
> all of it from the live run. See `docs/dev-day-issues.md`.

---

## ON-STAGE

### 0 · Hook (slides, ~6 min)
"You just built an agent that moves money. Who's in charge of it?" MCP/A2A say how
agents *connect*; nothing says who's *allowed* to do what — or proves it. That layer
is the control plane. Today we build one tool, then earn it a control plane, live.

### ① BUILD — Bob writes an MCP server from scratch (~10 min)

```bash
make bob-operator          # launch Bob (this same session also registers in ②)
```
Type to Bob (verbatim — tightened so the build is reliable):
> Create a new MCP server with fastmcp at `mcp-servers/sales-tax/server.py`: a tool
> `add_tax(amount, rate_pct=8.5)` returning `{amount, rate_pct, tax, total}`, plus a
> `/health` GET route using `@mcp.custom_route`, served with `transport="http"` on
> `0.0.0.0:8000`.

Then, in the 2nd terminal, prove it runs — **ungoverned**:
```bash
make stage1-build          # serves it bare on :8000, calls it → add_tax(100,8.5)=108.50
```
**Say:** "It works — and there's no token, no policy, no audit. Anyone on the network
could call it. *That's* the problem." Then **STOP touching the build.**

> ⚠️ Once 108.50 prints, do NOT re-prompt Bob to rebuild — a 2nd generation can be
> broken (issue #4). If the build ever fails: `make stage1-scaffold` → `make stage1-build`.

### ② GOVERN — put ContextForge in charge of the tool you built (~12 min)

```bash
make stage2-govern         # containerises sales-tax onto the mesh, retires the bare one
```
Back in the **operator** Bob session, type:
> Register the sales-tax service with finbyte-gateway at http://sales-tax:8000/mcp. Then list everything
> ContextForge is governing.

→ Bob calls `controlplane-register-mcp-server`; sales-tax joins the catalog. Show it
land in `make monitor`. **Say:** "In the catalog, token-gated — but Bob still can't
*call* it. Exposing a tool to an agent is a separate, privileged grant. That gate is
least-privilege."

```bash
make salestax-grant        # grants add_tax → Builder vserver + switches Bob to builder
bob                        # relaunch — now the BUILDER persona (config already written)
```
Type to Bob:
> Add sales tax to $100.

→ governed call through `:4444` → **108.50**. **Say:** "Same tool — built → governed
→ used. Every call now goes through one seam with a token and an audit trail." (Builder
sees *only* `sales-tax-add-tax` — point that out: least-privilege, verified.)

### ③ CONTROLS — the payoff: Bob meets the guardrails (~16 min)

```bash
make bob                   # analyst persona: a FinOps agent on the governed mesh
```
Drive Bob; after each, flip to `make monitor` Logs to show the enforcement. Tell Bob
to **USE the tool**, not describe it.

| Prompt to Bob | What the room sees |
|---|---|
| `Use the finbyte-gateway tools to fetch receipt rcpt_pii, verbatim.` | SSN / card / api-key **redacted before the model sees it**. |
| `Use the finbyte-gateway tools to fetch receipt rcpt_injection, verbatim.` | malicious memo → **`[INJECTION_BLOCKED]`**. |
| `Ask the auditor agent to pay $50,000 to Acme LLC.` | **BLOCKED** by policy (OPA). The same block fires on the Rust `a2a-payments` agent — cross-language. |
| `Wire $50k yourself.` | no `wire` tool — analyst can't reach it (**RBAC**). |

> These match what `make connect` prints. The explicit "use the … tools" / "ask the auditor agent" wording forces the right tool/agent call — plain phrasings like "show me the receipt" sometimes make Bob answer from memory instead of calling the tool.

**Say:** "Four controls, enforced at one seam, proven deterministically —
`make verify-controls` → 16/16. The agent tried; the control plane decided."

### 4 · Close + Q&A (~6 min)
Build → Govern → Prove. ContextForge is the control plane for agents: register → grant
→ call, enforce at the hook, prove it. CTA: IBM Bob trial + the repo; `make quickstart`
to run the finished mesh, `make dev-start` to walk the build.

---

## If it breaks on stage (don't debug live — switch tracks)

| Symptom | Move |
|---|---|
| Bob's build won't run | `make stage1-scaffold` → `make stage1-build` |
| "registered but not callable" | `make salestax-grant` then relaunch `bob` |
| Bob hangs on "Initializing…" | gateway down or stale config → it's pre-staged; worst case `make demo-reset` |
| A control doesn't fire | `make verify-controls` proves 16/16 out-of-band; show that |
| Total meltdown | `make quickstart` is the whole finished mesh in one command |

## Attendee access — the 3 paths

The mesh needs Docker + ~10 images; conference WiFi + 100 laptops is the real enemy.
So attendees pick one of **three** paths (this mirrors the picker in `docs/build.html`).
Full tiers in `docs/ONBOARDING.md`; the short version:

**1 · Codespaces + Bob** ⭐ — *hands-on, no local Docker.*
The mesh runs in a GitHub Codespace (the **Open in GitHub Codespaces** badge in the
README; the devcontainer runs `make up && make seed` in the cloud). The attendee drives
the **controls (Stage ③)** — they do **not** build their own tool on this path.
  1. **PORTS** tab → right-click **4444** → Port Visibility → **Public**.
  2. `make connect` (in the Codespace) → prints the one `bob mcp add … -t http …/mcp` line.
  3. Install only **IBM Bob** on the laptop, paste that line **from an empty folder**, run `bob`.
  - **Gotcha:** use the `-t http` + `/mcp` form — **never SSE** (Codespaces proxies buffer
    SSE → Bob hangs). Empty folder (a repo clone's `.bob/mcp.json` shadows it).
  - **No `gh`/codespace scope needed** — opening the Codespace and `make connect` are all
    in-browser / in-Codespace.

**2 · Fully local** — *the whole arc, including the build.*
Needs Docker + Bob locally. `make quickstart` for the finished mesh, or walk
`stage1-build → stage2-govern → stage3-controls → stage4-mesh`. **The only path where an
attendee builds their own tool** — building needs Bob, Docker, and the file all on one side.

**3 · Watch** — *zero setup.*
Open `docs/build.html` (`make dev-start`) for the read-along prompt cards, or watch the
presenter / the Companion `:7070` stream (share the URL/QR).

> **The build is local-only.** Bob *writing + governing* a tool (Stages ①–②) can't be split
> across laptop-and-Codespace, so it lives on the **Fully local** path. Codespaces is
> `make connect` + **Stage ③**; Bob isn't installed in the Codespace (it's the mesh host).

> Security note: `make connect` embeds an admin JWT and the port is public for the session —
> fine for short-lived throwaway-data demos; tear the Codespace down after.

---

## Commands the audience sees (that's the whole list)
`make bob-operator` · `make stage1-build` · `make stage2-govern` · `make salestax-grant`
· `bob` · `make bob` · `make monitor` — everything else is Bob talking.
