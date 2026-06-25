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

echo "== A2A chair: an AGENT orchestrates the quorum (discovers + delegates), wire still blocked =="
ch=$(curl -s "${AUTH[@]}" -X POST "$GW/rpc" -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"a2a-chair","arguments":{"message":{"role":"ROLE_USER","parts":[{"text":"Run the approval quorum for a $50000 wire to Acme LLC"}],"messageId":"qt-chair"}}}}')
printf '%s' "$ch" | grep -q "wire_blocked=true" && ok "chair agent ran the quorum; OPA blocked the wire" || no "chair should block (got: $(printf '%s' "$ch" | head -c 160))"

echo "  ── quorum: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] || exit 1
