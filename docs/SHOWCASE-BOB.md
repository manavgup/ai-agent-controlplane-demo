# Showcasing Bob — making the demo snazzy

The control-plane story is strong, but don't let Bob look like a button. Bob is an
**agentic IDE**: it plans, writes software, runs commands, and chains many steps
autonomously. These beats put *Bob's* capabilities on stage, with governance
visible the instant it acts. All verified live (IBM Bob v1.0.4 + this stack).

---

## Stage setup — two panes, cause → effect

Arrange your screen so the room sees the agent and the control plane at once:

```
┌──────────────────────────────┬───────────────────────────────┐
│  IBM Bob  (terminal)         │  ContextForge monitor (browser)│
│  the agent acting            │  /admin → Logs / Metrics       │
│  `bob`                       │  `make monitor`                │
└──────────────────────────────┴───────────────────────────────┘
        (optionally a 3rd pane: `make inspect-mcp`)
```

- **Narrative framing** (say it out loud): *"We've handed Bob the keys to FinByte's
  expense & payments workflow. Watch what it tries — and how the control plane keeps
  it safe."* Before the $50k beat: *"Bob is about to wire fifty thousand dollars to a
  vendor it met two minutes ago."*
- **Punchy act order:** end **Act 1** on the $50k block (the gasp); open **Act 2**
  with Bob *building and onboarding* a service (the "wait — it operates the control
  plane too?").
- **Reality check, every beat:** tell Bob to **use the finbyte-gateway tools**, and
  glance at the monitor's **Logs** — a real gateway line means Bob actually called;
  no line means it narrated from the repo. (See Troubleshooting in the RUNBOOK.)

---

## Beat 1 — Bob autonomously works the queue  *(Act 1 · the orchestration showcase)*

Persona: **analyst** — `make bob-install` (8 tools, no wire). One prompt, one
autonomous run that hits **all four controls** in a realistic task:

> **"Process today's pending expenses end to end. For each one: read it, check its
> receipt, approve and reimburse anything clean, and flag anything that needs a wire."**

What the room watches Bob do (4 expenses in the queue):

| Expense | Bob's step | Control that fires |
|---|---|---|
| `exp_clean` ($18) | reads, approves, reimburses | — (clean baseline) |
| `exp_pii` ($240) | reads the receipt | **PII/secret redacted** (`***-**-6789`, `[SECRET_REDACTED]`) |
| `exp_injection` ($65) | reads the receipt | **injection neutralized** (`[INJECTION_BLOCKED]`) |
| `exp_big` ($50,000) | needs a wire → delegates to the **auditor agent** | **OPA blocks it** (cross-language Python→Rust) |

This is the snazzy version of the money shots: not contrived single calls, but Bob
**planning and orchestrating** a batch — and the $50k block lands as a dramatic
interruption mid-flow. Reset fixtures between runs with `make demo-reset`.

---

## Beat 2 — Bob builds & onboards a tool  *(Act 2 opener · the agentic-IDE showcase)*

The signature move: Bob **writes code**, then onboards it to the governed mesh. The
repo ships `mcp-servers/fx-rates/server.py` as a **base** (just `get_fx_rate` +
`list_currencies`) so Bob has something to extend.

Persona: **operator** — `make bob-install-operator` (Bob can edit files *and* call
the operator tools in one session).

1. **Build** — Bob writes the tool:
   > **"Finance needs currency conversion. Add a `convert(amount, base, quote)` tool
   > to `mcp-servers/fx-rates/server.py` that uses the existing rates."**
2. **Deploy** — rebuild the container (you run it, or let Bob run it for extra flair):
   ```bash
   docker compose up -d --build fx-rates
   ```
3. **Onboard + use** — Bob registers it and immediately uses the new governed tool:
   > **"Register the fx-rates service at http://fx-rates:8000/mcp."**
   > **"Now convert 1000 USD to EUR with the new tool."**   → `{"converted": 920.0}`

The line to land: ***"An AI just wrote a service — and the control plane is already
governing it."*** (`fx-rates-convert` now shows up in `make inspect-mcp` and the monitor.)

**Reliability nets** (live coding is variable):
- If Bob's edit wobbles: **`make fxrates-convert`** drops in the finished version
  (`server_with_convert.py`) and rebuilds — one keystroke, then continue at step 3.
- To repeat the beat cleanly: **`make fxrates-reset`** restores the base, and
  **`make seed`** un-registers fx-rates so Bob can onboard it again.

---

## Beat 3 — Bob thinks out loud  *(plan mode)*

Make the agent's reasoning legible. Run a beat (Beat 1 is ideal) in plan mode so the
room sees Bob's plan before it executes:

```bash
bob --chat-mode plan "Process today's pending expenses end to end."
```

Bob lays out the steps it intends to take, then proceeds — a cheap way to show that
this is genuine multi-step reasoning, not a script.

---

## Reset / repeatability cheatsheet

| To reset… | Command |
|---|---|
| The stack + fixtures (between runs) | `make demo-reset` |
| fx-rates back to base (repeat Beat 2) | `make fxrates-reset` then `make seed` |
| Bob persona | `make bob-install` (analyst) / `make bob-install-operator` |
| Prove everything still works | `make verify-controls` → 16/16 |

> After any reseed the FinOps/Operator UUID changes — re-run `make bob-install`
> (or `bob-install-operator`) and restart Bob.
