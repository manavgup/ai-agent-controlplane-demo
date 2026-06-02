# IBM Bob × ContextForge — Who's in charge of your agents?

Conference talk, ~45 min, mixed exec + technical audience.
This file is the **source of truth**: `build_deck.py` renders these slides and
speaker notes into `bob-controlplane-talk.pptx`.

- **Story:** A FinByte fintech developer uses IBM Bob (an agentic IDE / MCP client)
  to build & operate an automated expense-and-payments workflow over a mesh of
  MCP servers + 2 cross-language A2A agents, all governed by **ContextForge**
  (IBM/mcp-context-forge), the **AI agent control plane**. Then the developer
  flips roles and uses Bob to **operate the control plane itself**.
- **Spine:** Act 1 — four "money shots" (Policy, Data protection, Prompt-injection,
  Least-privilege/RBAC), each proven deterministically by `make verify-controls`.
  Act 2 — Bob as a privileged **operator** persona: list the catalog, interrogate
  the policy, register a new server, read the audit trail.
- **Delivery:** attendees run it **live on their laptops** via one command
  (`make quickstart`), and watch governance with the real ecosystem tools:
  **ContextForge's monitor**, **MCP Inspector**, **A2A Inspector**.
- **Theme:** IBM-ish blue `#0F62FE`; dark title/section/close slides, light content
  slides; monospace for prompts / code / blocked-reasons.

All facts below are validated live in this repo (gateway plugins, Rego policy,
fixtures, Python + Rust agents, the operator MCP server, the seed script, and a
real IBM Bob v1.0.4 session).

---

## Part A — The Talk (~14 slides)

1. **Title** — "IBM Bob × ContextForge — Who's in charge of your agents?"
2. **The problem** — MCP gave agents tools; A2A gives agents each other. Who's in
   charge when an agent pays another agent?
3. **MCP vs A2A** — vertical vs horizontal; two protocols, one missing layer.
4. **The cast / FinByte** — IBM Bob + 4 business MCP servers (expense-db,
   erp-payments, policy-docs, notify) + an **operator surface** (controlplane) +
   2 cross-language A2A agents (Auditor=Python, Payments=Rust). (fx-rates exists
   unregistered for the Act-2 live registration.)
5. **Architecture** — Bob → ContextForge (:4444) → backends; OPA sidecar (:8181);
   one governed seam. You *watch* it via ContextForge's monitor + MCP/A2A Inspectors.
6. **The control-plane idea** — enforce at the tool hooks (`tool_pre_invoke` /
   `tool_post_invoke`), including the bridged `a2a_<name>` calls.
7. **Money shot #1 — Policy (OPA/Rego).** $50,000 wire BLOCKED; $5k or $50k+approval
   ALLOWED; the SAME block fires on the bridged `a2a-payments` agent call.
8. **Money shot #2 — Data protection.** SSN/card/api-key masked before the model sees it.
9. **Money shot #3 — Prompt-injection.** Malicious receipt memo → `[INJECTION_BLOCKED]`.
10. **Money shot #4 — Least-privilege/RBAC.** FinOps server has no `wire`; only
    Treasury reaches it. (+ rate limits named.)
11. **Act 2 — Bob operates the control plane.** A privileged **operator** persona
    (separate from the least-privilege analyst — RBAC made concrete): `list_control_plane`,
    `evaluate_policy` (interrogate OPA live), `register_mcp_server` (add fx-rates LIVE),
    `recent_blocks` (audit trail). The thesis made literal: the agent operating the
    plane that governs it.
12. **Proof + watch it** — `make verify-controls` (16 deterministic assertions);
    governance is visible in the real tools: ContextForge **monitor** (Logs/Metrics),
    **MCP Inspector** (8 governed tools, wire absent; redaction on a live call),
    **A2A Inspector** (both agent cards). Cross-language proven by the Rust agent.
13. **Also in the box** — SSO/IdPs, Cedar, federation, SIEM export (named, not demoed).
14. **Takeaways + CTA** — one governed seam; enforce at the bridged hook; let the
    agent operate the plane; prove it. Try the trial + repo.

## Part B — Follow-Along Appendix (~7 slides), run LIVE

15. **Before you arrive** — Docker Desktop (running), `uv`, IBM Bob (`bob`),
    Node.js ≥18 (`npx`, for MCP Inspector). IBM Bob 30-day trial; clone the repo.
16. **Bring it all up — ONE command** — `make quickstart`: preflight → stack →
    seed → Bob configured → `verify-controls` 16/16 → prints a walkthrough card.
    Re-run if anything stalls.
17. **Drive Bob — personas** — Bob talks to the gateway through the
    `mcpgateway.wrapper` stdio bridge (NOT a hand-pasted SSE url). `make bob-install`
    = FinOps **analyst** (8 tools, no wire); `make bob-install-operator` = **operator**.
    Re-run after any reseed (the FinOps/Operator UUID changes). `bob mcp list` shows
    a static "Disconnected" until a live session.
18. **Act 1 in Bob (analyst)** — exact prompts: fetch `rcpt_pii` (redacted), fetch
    `rcpt_injection` (neutralized), "ask the auditor agent to pay $50,000 to Acme"
    (blocked, cross-language), "wire $50k yourself" (no wire tool). Tell Bob to USE
    the tool; verify it's real in the monitor Logs (no log = it narrated).
19. **Act 2 in Bob (operator)** — `make bob-install-operator`; then list / evaluate
    policy / register fx-rates / recent blocks.
20. **Watch the control plane — the 3 tools** — `make monitor` (Admin UI),
    `make inspect-mcp` (MCP Inspector → gateway FinOps endpoint, Streamable HTTP +
    bearer; 8 tools, wire absent; call get_receipt → redacted in the inspector),
    `make inspect-a2a` (A2A Inspector :8090 → host.docker.internal:9001 / :3000).
21. **Troubleshooting** — UUID-changes-on-reseed → re-run `bob-install`; "Bob
    narrates instead of calling a tool" → tell it to use the tool, check the monitor;
    `make demo-reset`; A2A Inspector first-run build is slow; `make demo` for the
    auto-paced walkthrough.

---

## Speaker-notes conventions
- Each slide's notes carry the full talk track + exact commands. ≈30 talk + 12
  live + 3 Q&A.
- Verbatim strings to keep on slides + notes:
  - Block: `Plugin Violation: Wire amount 50000 exceeds the $10,000 auto-approve
    limit and requires dual approval (approval=true). FinByte T&E policy §2.`
  - Masked: `SSN ***-**-6789, card ****-****-****-1111 ... api key [SECRET_REDACTED]`
  - Injection neutralized to: `[INJECTION_BLOCKED]`
  - Rust agent success: `Payment executed: ...`
- Connectivity reality (Part B step 17): wrapper crashes without
  `DATABASE_URL=sqlite:////tmp/mcpwrapper.db`; token must be a REGISTERED user
  (admin@finbyte.demo) — a bob@finbyte.demo token 401s; least-privilege is the
  FinOps virtual server, not the token identity.
