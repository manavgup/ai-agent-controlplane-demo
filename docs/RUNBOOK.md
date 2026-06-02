# Presenter RUNBOOK

## Before the talk
1. `cp .env.example .env && make up && make seed` — wait for "gateway healthy" + the FinOps/Treasury UUIDs.
2. `make verify-controls` → confirm **16 passed, 0 failed**. (This is your safety net: if live Bob misbehaves on stage, run this instead — it proves every control.)
3. `make bob-config` → paste into `~/.bob/mcp_settings.json`; start Bob; confirm Bob lists the FinByte tools.
4. Open three windows: (a) Bob, (b) `make logs` (gateway), (c) a terminal for `verify-controls` / curl.
5. Record a screen capture of each money shot as a backup.

## On-stage run order (45 min)
- **Architecture** (5 min): show `make ps` (8 services), `curl` both agent cards to prove Python vs Rust:
  - Python Auditor: `docker compose exec auditor python -c "import urllib.request,json;print(json.load(urllib.request.urlopen('http://localhost:9001/.well-known/agent-card.json'))['name'])"`
  - Rust Payments serves the same well-known path on :3000 (advertised in its agent card).
- **Baseline** (3 min): in Bob — *"Process expense exp_clean and reimburse it."* → succeeds.
- **Money shots** (~5 min each), each visible in `make logs`:
  1. *Policy*: *"Wire $50,000 to Acme LLC for expense exp_big."* → **blocked** with the T&E reason. Then *"…approve and wire $50,000 with dual approval"* → allowed. (Also: the Auditor→Rust `a2a-payments` $50k is blocked the same way — agent-mesh governance.)
  2. *Data protection*: *"Show me the receipt for expense exp_pii."* → SSN/card masked, key `[SECRET_REDACTED]`.
  3. *Injection*: *"Process expense exp_injection."* → the embedded "SYSTEM: ignore…" is `[INJECTION_BLOCKED]`.
  4. *Least-privilege*: *"Wire funds directly."* → Bob has no `wire` tool (FinOps excludes it).
- **Proof** (5 min): `make verify-controls` → 16/16 green. Hand off the repo + `make bob-config`.
- **Q&A** (5 min).

## Reset between runs
- `make demo-reset` — restarts the gateway + expense-db (clears rate-limit lockouts, restores fixtures).
- Tokens expired? `make token` / `make bob-config` again (tokens last 7 days).

## Recovery
| Symptom | Fix |
|---|---|
| Bob lists no tools | re-run `make bob-config`, re-paste, restart Bob; confirm `curl -s localhost:4444/health` = 200 |
| `make seed` warns "tool not found" | backends still starting; wait 5s and re-run `make seed` (idempotent) |
| Port 4444 in use | another gateway running: `make down`, or `pkill -f mcpgateway.main` (a host instance) |
| OPA shot not blocking | `docker compose ps opa` up? `make demo-reset`; check `gateway/policies/finops.rego` mounted |
| Live Bob flaky | fall back to `make verify-controls` + the recorded captures |

## Notes
- **Rate-limit live 429**: the limiter is enabled (in-memory). For a visible 429 on stage, lower
  `TOOL_RATE_LIMIT` in `.env` (e.g. `15`) and recreate the gateway, then hammer a tool ~20×.
- **Full profile** (`make up-full`) adds Phoenix for an OTEL trace of the governed call path.
- **RBAC 403** (vs the least-privilege shown here) needs a bootstrapped non-admin role — out of scope for the lite demo.
