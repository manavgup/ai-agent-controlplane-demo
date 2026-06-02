#!/usr/bin/env bash
# Deterministic proof that the four controls work. Asserts block/allow on each
# money shot through the live gateway. Exits non-zero on any regression.
# Usage: bash scripts/money-shots/run-all.sh   (or `make verify-controls`)
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

GW=${GATEWAY_URL:-http://localhost:4444}
SECRET=${JWT_SECRET_KEY:-demo-only-change-me-0123456789abcdef}
TOKEN=$(DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- \
  python -m mcpgateway.utils.create_jwt_token -u admin@finbyte.demo --admin -e 10080 -s "$SECRET" 2>/dev/null | tail -1)

PASS=0; FAIL=0
call() { # name, args-json
  curl -s -X POST "$GW/rpc" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}"
}
assert_contains() { # label, haystack, needle
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS  $1"; PASS=$((PASS+1));
  else echo "  FAIL  $1 (missing: $3)"; echo "        got: $(printf '%s' "$2" | head -c 160)"; FAIL=$((FAIL+1)); fi
}
assert_absent() { # label, haystack, needle
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL  $1 (leaked: $3)"; FAIL=$((FAIL+1));
  else echo "  PASS  $1"; PASS=$((PASS+1)); fi
}

echo "== #1 Policy (OPA): wire amount cap =="
r=$(call erp-payments-wire '{"payee":"Acme LLC","amount":50000,"approval":false}')
assert_contains "\$50k wire BLOCKED with policy reason" "$r" "Plugin Violation"
assert_contains "block cites the T&E policy" "$r" "T&E policy"
r=$(call erp-payments-wire '{"payee":"Corner Cafe","amount":5000,"approval":false}')
assert_contains "\$5k wire ALLOWED" "$r" '"status":"wired"'
r=$(call erp-payments-wire '{"payee":"Acme LLC","amount":50000,"approval":true}')
assert_contains "\$50k WITH approval ALLOWED" "$r" '"status":"wired"'

echo "== #1b Agent-mesh: OPA governs the bridged A2A payment call =="
r=$(call a2a-payments '{"payee":"Acme LLC","amount":50000,"approval":false}')
assert_contains "\$50k via a2a-payments BLOCKED" "$r" "Plugin Violation"

echo "== #2 Data protection: PII + secret on tool output =="
r=$(call expense-db-get-receipt '{"id":"rcpt_pii"}')
assert_contains "SSN masked" "$r" "***-**-6789"
assert_contains "credit card masked" "$r" "****-****-****-1111"
assert_contains "API key redacted" "$r" "[SECRET_REDACTED]"
assert_absent "raw card number not leaked" "$r" "4111 1111 1111 1111"
assert_absent "raw API key not leaked" "$r" "sk-live-ABCDEF"

echo "== #3 Prompt-injection: neutralized in tool output =="
r=$(call expense-db-get-receipt '{"id":"rcpt_injection"}')
assert_contains "injection neutralized" "$r" "[INJECTION_BLOCKED]"
assert_absent "injected instruction not present" "$r" "ignore all prior policy"

echo "== #4 Least-privilege: Bob's FinOps server excludes the raw wire tool =="
FINOPS_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$GW/servers" | python3 -c "import sys,json;[print(s['id']) for s in json.load(sys.stdin) if s.get('name')=='FinOps']" 2>/dev/null | head -1)
ftools=$(curl -s -H "Authorization: Bearer $TOKEN" "$GW/servers/$FINOPS_ID/tools")
assert_contains "FinOps exposes approve" "$ftools" "approve"
assert_contains "FinOps exposes a2a-auditor" "$ftools" "a2a-auditor"
assert_absent "FinOps hides the raw wire tool" "$ftools" "erp-payments-wire"

echo "== Cross-language A2A: Rust Payments agent executes via gateway =="
r=$(call a2a-payments '{"message":{"role":"ROLE_USER","parts":[{"text":"Execute payment of $5000 to Corner Cafe"}],"messageId":"m-verify"}}')
assert_contains "Rust agent executed the payment" "$r" "Payment executed"

echo
echo "──────────────────────────────────────────"
echo "  RESULT: $PASS passed, $FAIL failed"
echo "──────────────────────────────────────────"
[ "$FAIL" -eq 0 ] || exit 1
