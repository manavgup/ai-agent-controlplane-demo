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
4. **PORTS** tab → right-click **4444** → **Port Visibility → Public**.
5. `make connect` → prints the filled-in `bob mcp add … -t http …/mcp` line for laptop Bob.
6. Sanity check: open **`:4444/admin`** (`admin@finbyte.demo` / `FinByteAdmin!2026`) — the
   ContextForge admin UI listing every server/tool/agent. (Forwarded ports are private by default;
   the admin UI works in-Codespace without flipping visibility.)

> ⚠️ Use the `-t http` + `/mcp` form `make connect` prints — **never SSE** (Codespaces proxies
> buffer SSE and Bob hangs). Paste it **from an empty folder** (a repo clone's `.bob/mcp.json`
> shadows it). Tear the Codespace/port down after — `make connect` embeds an admin token.

## 👀 Audience follow-along (non-coders, no GitHub)

Put the QR (`docs/assets/follow-qr.png`) on a slide → it opens
**`follow.html`**: a plain-English, tap-along "YOU ARE HERE" stage tracker. Zero setup, no terminal.
A collapsed "🙋 Want to try it yourself?" card holds the optional hands-on lane (install Bob, paste
the one `make connect` line you show on screen, type `bob`). `build.html` stays the deeper, coder
version for the technical crowd.

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
| `Pay the $50,000 invoice to Acme Corp.` | **BLOCKED** by policy (OPA). The same block fires on the Rust `a2a-payments` agent — cross-language. |
| `Show me receipt rcpt_pii.` | SSN / card / api-key **redacted before the model sees it**. |
| `Show me receipt rcpt_injection.` | malicious memo → **`[INJECTION_BLOCKED]`**. |
| `Wire $50k yourself.` | no `wire` tool — analyst can't reach it (**RBAC**). |

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
