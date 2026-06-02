# IBM Bob × ContextForge — Who's in charge of your agents?

Conference talk, ~45 min, mixed exec + technical audience.
This file is the **source of truth**: `build_deck.py` renders these slides and
speaker notes into `bob-controlplane-talk.pptx`.

- **Story:** A FinByte fintech developer uses IBM Bob (an agentic IDE / MCP client)
  to build an automated expense-and-payments workflow. Bob orchestrates a mesh of
  4 MCP servers + 2 A2A agents through **ContextForge** (IBM/mcp-context-forge),
  the **AI agent control plane**. Every tool call — including agent-to-agent
  payment calls — is governed at one seam.
- **Spine:** four "money shots" (Policy, Data protection, Prompt-injection,
  RBAC + rate limits), each proven deterministically by `make verify-controls`.
- **Theme:** IBM-ish blue `#0F62FE` accent; dark title/section/close slides,
  light content slides; monospace for prompts / code / blocked-reasons.

All facts below are validated in this repo (gateway plugins, Rego policy,
fixtures, Python + Rust agents, seed script).

---

## Part A — The Talk (~13 slides)

1. **Title** — "IBM Bob × ContextForge — Who's in charge of your agents?"
   Subtitle: the AI agent control plane. Speaker + venue line.
2. **The problem** — MCP gave agents tools. A2A gives agents *each other*.
   Who is in charge when an agent pays another agent? (the ungoverned mesh).
3. **MCP vs A2A** — vertical (model → tools) vs horizontal (agent → agent);
   two protocols, one missing thing: a place to enforce policy.
4. **The cast / FinByte** — IBM Bob + 4 MCP servers + Auditor (Python) +
   Payments (Rust). One automated expense-and-payments workflow.
5. **Architecture** — the embedded diagram: Bob → ContextForge (:4444) →
   [4 MCP + a2a_auditor + a2a_payments]; OPA sidecar (:8181). One governed seam.
6. **The control-plane idea** — enforcement at the gateway tool hooks
   (`tool_pre_invoke` / `tool_post_invoke`), *including the bridged `a2a_<name>`
   calls* — so agent→agent payments are governed too.
7. **Money shot #1 — Policy (OPA/Rego).** $50,000 wire BLOCKED; $5k or
   $50k+approval ALLOWED; blocks the agent-to-agent call too.
8. **Money shot #2 — Data protection (PII + secrets).** SSN / card / api-key
   masked before the model sees the receipt.
9. **Money shot #3 — Prompt-injection.** A malicious receipt memo neutralized to
   `[INJECTION_BLOCKED]` before Bob can act.
10. **Money shot #4 — RBAC + rate limits.** Least-privilege: FinOps server has no
    `wire`; only Treasury reaches it. Built-in rate limiter (429 + lockout).
11. **Proof** — `make verify-controls` (16 deterministic block/allow assertions) +
    the gateway audit log; cross-language A2A proven by both agent cards + Rust
    "Payment executed".
12. **Also in the box** — SSO / 7 IdPs, Cedar, federation, SIEM export
    (named, not demoed).
13. **Takeaways + call to action** — one governed seam; enforce at the bridged
    hook; try the trial + repo.

## Part B — Follow-Along Appendix (~7 slides)

14. **Before you arrive** — IBM Bob 30-day trial (bob.ibm.com, IBMid), install Bob,
    clone the repo.
15. **Bring it up** — `cp .env.example .env`; `make up`; `make seed`
    (prints the FinOps UUID).
16. **Wire Bob to the control plane** — `make bob-config` (or `make token-bob`);
    paste into `.bob/mcp.json` (SSE url + bearer JWT + alwaysAllow).
17. **Scenario A — Baseline & Policy** — "Process expense exp_clean and reimburse it."
    then "Wire $50,000 to Acme LLC for expense exp_big." (BLOCKED) → "...with dual approval" (allowed).
18. **Scenario B — Data protection & Injection** — "Show me the receipt for expense exp_pii."
    (masked); "Process expense exp_injection." (instruction blocked).
19. **Scenario C — Least-privilege** — "Wire funds directly." → Bob can't see the
    wire tool (not in FinOps).
20. **Troubleshooting** — common gotchas: token expiry, SSE url/UUID, 429 lockout
    reset, A2A enable flag, plugins not loading.

---

## Speaker-notes conventions
- Each slide's `notes_slide.notes_text_frame` carries the full talk track + exact
  commands. Timings are suggestions to land the talk in 45 min (≈ 30 talk + 12
  live demo + 3 Q&A).
- Exact strings to keep verbatim on slides + notes:
  - Block reason: `Plugin Violation: Wire amount 50000 exceeds the $10,000
    auto-approve limit and requires dual approval (approval=true). FinByte T&E policy §2.`
  - Masked receipt: `SSN ***-**-6789, card ****-****-****-1111 ... api key [SECRET_REDACTED]`
  - Injection neutralized to: `[INJECTION_BLOCKED]`
  - Rust agent success: `Payment executed: ...`
