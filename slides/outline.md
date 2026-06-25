# IBM Bob × ContextForge — Who's in charge of your agents? (Bob Developer Day)

Conference talk, ~40 min, **Bob Developer Day** (developer-leaning audience).
This file is the **source of truth**: `build_deck.py` renders these slides and
speaker notes into `bob-controlplane-talk.pptx`.

- **Story:** A FinByte developer uses IBM Bob (an agentic IDE / MCP client) to
  **build an MCP server from scratch**, then **earn it a control plane** —
  ContextForge (IBM/mcp-context-forge), the **AI agent control plane** — one
  layer at a time. The talk is told bottom-up, the inverse of `make quickstart`:
  you assemble the finished governed mesh by hand and watch each layer go in.
- **Spine:** the progressive build — **build → govern → use → control → mesh** —
  carrying ONE artifact (the `sales-tax` server Bob writes in Stage ①) the whole
  way. The throughline is **`register → grant → call`**: works-but-ungoverned →
  in the catalog but not callable → granted & callable through the one governed
  seam. Three personas (**builder / analyst / operator**) make RBAC concrete.
- **Stage ③ = the four controls** (Policy/OPA, Data protection, Prompt-injection,
  RBAC + rate limits), each proven deterministically by `make verify-controls`
  (`16 passed, 0 failed`).
- **Delivery:** attendees run it **live on their laptops** — `make dev-start`
  walks the build path; `make quickstart` is the one-command finished mesh. They
  watch governance with the real ecosystem tools: **ContextForge's monitor**,
  **MCP Inspector**, **A2A Inspector** (or `make cockpit` for all of it).
- **Theme:** IBM-ish blue `#0F62FE`; dark title/section/close slides, light
  content slides; monospace for prompts / code / blocked-reasons.

All facts below are validated live in this repo (gateway plugins, Rego policy,
fixtures, Python + Rust agents, the operator MCP server, the seed/grant scripts,
the sales-tax stage-1→2 flow, and a real IBM Bob v1.0.4 session).

---

## Part A — The Talk (~18 slides: Act 0 framing, then the dev journey)

1. **Title** — "IBM Bob × ContextForge — Who's in charge of your agents?"
   (Bob Developer Day). Tagline: *build an agent tool with Bob, then watch it
   earn a control plane, one layer at a time.*
2. **AI Agent 101 — "What is an agent?"** — *(SVG `agent-101.svg` → `agent-101.png`)*
   a central LLM "brain" hub wired to five traits: 🧠 reasoning/planning · 💾 memory ·
   🛠️ tools/actions (executes tasks) · 📚 knowledge · 🎯 autonomy. The leap from
   *answers* to *acts* is the power — and the risk: the moment it can act, someone
   must be in charge of it.
3. **MCP — the problem it solves** — every model↔tool integration was bespoke
   (N×M glue). MCP standardizes the **vertical** seam (model → tools): speak it once,
   reach any tool. Bob uses it for every server in the demo.
4. **A2A — the problem + the result** — agents need to call *other* agents across
   vendors/languages with no standard handshake. A2A standardizes the **horizontal**
   seam (agent → agent). Result: the Python `auditor` ↔ Rust `payments` pair. Same
   enforcement must sit on both seams.
5. **Thesis — "Building agents is easy. Governing them is the hard part."** — Bob
   stands up a money-moving server in 30 s, wide open. MCP/A2A say *how* agents
   connect; neither says *who's allowed to do what*, or proves it. That missing layer
   is the AI agent control plane — the rest of the talk earns one.
6. **Architecture overview (the harness)** — the existing diagram, framed forward:
   one checkpoint every tool call *and* every agent-to-agent call passes through.
   "We build this by hand." (Bookends with slide 17.)
7. **Three ways to follow along** — the chooser (moved up): 👀 phone (no install) ·
   🧪 laptop Bob · 💻 full local. Scan now, follow from your seat; how-to in the appendix.
8. **The progressive build (spine)** — build → govern → use → control → mesh; the
   inverse of `make quickstart`. ONE artifact carried the whole way; the throughline
   is `register → grant → call`.
9. **① Build** — Bob writes `mcp-servers/sales-tax/server.py` from scratch
   (`make stage1-build`). Runs bare on `:8000`; `add_tax(100) → 108.50`. Works — and
   totally ungoverned. That exposure is what Stage ② fixes.
10. **② Govern** — `register → grant → call`. REGISTER (operator) → catalog, *not
    callable yet*; GRANT (privileged) → into a `Builder` vserver, *least-privilege*;
    CALL (builder) → `108.50` through the gateway. Enforced at `tool_pre_invoke` /
    `tool_post_invoke`. 2b: Bob extends `fx-rates` with `convert`.
11. **Now the room builds agents (live)** — Bob just registered the sales-tax server;
    now the room does too. Attendees scan the on-screen QR, name an agent with their
    initials, register it — the projected `/wall` count climbs 0 → N, live. The
    abstract `register` step becomes a shared moment.
12. **Three personas** — builder / analyst / operator. Same binary, three actors —
    RBAC by which virtual server the persona points at.
13. **③ Control — Policy (OPA/Rego).** $50,000 wire BLOCKED; the SAME block fires on
    the bridged `a2a-payments` agent call.
14. **③ Control — Data protection.** SSN/card/api-key masked before the model sees it.
15. **③ Control — Prompt-injection.** Malicious memo → `[INJECTION_BLOCKED]`.
16. **③ Control — Least-privilege/RBAC + rate limits.** FinOps has no `wire`.
17. **④ Mesh — "you just built this diagram"** — callback to slide 6: you earned every
    layer by hand; identical to `quickstart`'s end-state. `make verify-controls →
    16 passed, 0 failed`. Watch it in monitor / MCP Inspector / A2A Inspector.
18. **Takeaways + also-in-the-box + CTA** — one throughline; `register → grant → call`;
    enforce at the hook (a2a governed too); three personas; prove it (16/16 + audit).
    CTA: IBM Bob trial + the repo.

## Part B — Follow-Along Appendix (~6 slides), run LIVE

The chooser now lives up front (Part A slide 7); the appendix is the detailed how-to.

19. **T1 📱 Phone** — scan the QR → follow-along page → run the three governed
    scenarios (PII redacted / injection neutralised / $50k blocked). No install.
20. **T2 🧪 Laptop Bob** — install Bob → dashboard's 🔌 Connect Bob → copy the
    command / download settings.json / one-liner (no token typing) → drive the
    three canonical prompts → governed. Same cloud control plane.
21. **T3 💻 Full local — build & govern** — `make quickstart` (finished, 16/16) or
    walk ① `make stage1-build` (→108.50 ungoverned) → ② register→grant→call
    (→108.50 governed).
22. **T3 💻 Full local — controls + proof** — `make stage3-controls` + the three
    analyst prompts + `make verify-controls` → 16 passed, 0 failed.
23. **Watch the control plane** — `make monitor` / `make inspect-mcp` /
    `make inspect-a2a` (or `make cockpit`); plus the dashboard's 🛡️ Agentic AI
    Control Plane link → MCP Servers → your `salestax-<INI>` in the catalog.
24. **Troubleshooting** — stage-1 wobble → `make stage1-scaffold` / `make stage-reset`;
    registered-but-not-callable → `make salestax-grant` + `bob-install-builder`;
    UUID-changes-on-reseed → re-run the matching install; "Bob narrates" → tell it
    to USE the tool, check Logs; 422 `SSRF_DNS_FAIL_CLOSED` → `make salestax-up`;
    phone can't reach a Codespaces public port → expected, presenter uses
    `make present` (cloudflared). `make demo-reset` / `make agents-reset`.

---

## Speaker-notes conventions
- Each slide's notes carry the full talk track + exact commands. ≈28 talk + 12
  live + 3 Q&A.
- Verbatim strings to keep on slides + notes:
  - Stage-1 proof: `add_tax(100, 8.5) → tax=8.50, total=108.50`
  - Block: `Plugin Violation: Wire amount 50000 exceeds the $10,000 auto-approve
    limit and requires dual approval (approval=true). FinByte T&E policy §2.`
  - Masked: `SSN ***-**-6789, card ****-****-****-1111 ... api key [SECRET_REDACTED]`
  - Injection neutralized to: `[INJECTION_BLOCKED]`
  - Rust agent success: `Payment executed: ...`
- The throughline to repeat: **register → grant → call** — registering a backend
  only catalogs its tools; granting it to an agent is a separate, privileged step;
  that boundary is least-privilege.
- Connectivity reality (Part B): wrapper crashes without
  `DATABASE_URL=sqlite:////tmp/mcpwrapper.db`; token must be a REGISTERED user
  (admin@finbyte.demo) — a bob@finbyte.demo token 401s; least-privilege is the
  virtual server scope, not the token identity. The virtual-server UUID changes on
  every reseed — re-run the matching `make bob` / `bob-operator` / `bob-install-builder`.
