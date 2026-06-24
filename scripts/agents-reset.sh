#!/usr/bin/env bash
# agents-reset.sh — `make agents-reset`: remove every room-built salestax-* agent
# from the ContextForge catalog, resetting the live "agents built by the room"
# count back to 0. Pairs with the Companion register button + /wall.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SECRET="${SECRET:-demo-only-change-me-0123456789abcdef}"
BASE="${GATEWAY_URL:-http://localhost:4444}"

ADMIN=$(DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- \
  python -m mcpgateway.utils.create_jwt_token -u admin@finbyte.demo --admin -e 10080 -s "$SECRET" 2>/dev/null | tail -1)
[ -n "$ADMIN" ] || { echo "agents-reset: could not mint a token (is uv here and the gateway up?)"; exit 1; }

uv run --with httpx python - "$BASE" "$ADMIN" <<'PY'
import sys, httpx
base, token = sys.argv[1], sys.argv[2]
H = {"Authorization": "Bearer " + token}
try:
    gws = httpx.get(base + "/gateways", headers=H, timeout=15).json()
except Exception as e:
    print(f"agents-reset: cannot reach gateway at {base}: {e}"); sys.exit(1)
n = 0
for g in gws if isinstance(gws, list) else []:
    if isinstance(g, dict) and g.get("name", "").startswith("salestax-"):
        try:
            httpx.request("DELETE", base + "/gateways/" + g["id"], headers=H, timeout=15)
            n += 1
        except Exception:
            pass
print(f"removed {n} room agent(s) (salestax-*) — count reset to 0")
PY
