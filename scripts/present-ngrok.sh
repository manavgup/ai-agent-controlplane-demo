#!/usr/bin/env bash
# present-ngrok.sh — THE demo-day command for the laptop + ngrok room setup.
#
# Chains the exact bring-up validated on 2026-07-22, idempotently: each layer
# is skipped if it's already healthy, so it's safe to re-run mid-demo (a
# re-run will NOT wipe the room counter — run `make agents-reset` yourself
# for a clean start before doors open).
#
# Why not `make present`? That path uses cloudflared quick-tunnels, which
# rate-limited during a live demo. This uses the reserved ngrok domain, so
# the QR on the slide never changes.
set -u

DOMAIN="${NGROK_DOMAIN:-obstruct-sweat-elephant.ngrok-free.dev}"
URL="https://${DOMAIN}"
NGROK_LOG=/tmp/ngrok-demo.log
COMPANION_LOG=/tmp/companion-demo.log

step() { printf '\n\033[1;36m── %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

step "1/6 container runtime"
if docker info >/dev/null 2>&1; then ok "docker socket answering"
else
  podman machine start || { warn "podman machine failed to start"; exit 1; }
  ok "podman machine started"
fi

step "2/6 lite stack + seed (gateway :4444)"
if curl -sf -m 3 localhost:4444/health >/dev/null 2>&1; then
  ok "gateway already healthy — skipping up/seed"
else
  make up && make seed || { warn "make up/seed failed"; exit 1; }
fi

step "3/6 sales-tax backend (registrations resolve against it)"
if docker ps --format '{{.Names}}' | grep -q sales-tax; then
  ok "sales-tax already running"
else
  # --no-build: the image is cached; a rebuild can die on Docker Hub auth
  docker compose -f docker-compose.yml -f docker-compose.salestax.yml up -d --no-build sales-tax \
    || warn "sales-tax didn't start — phone registration will 422 until it does"
fi

step "4/6 tunnels — ngrok $DOMAIN → :7070, cloudflared → :4444 (Tier-2 Bob laptops)"
# ngrok free = ONE endpoint URL: a second http tunnel gets POOLED onto the same
# static domain (round-robin — phones would randomly hit the gateway). So the
# gateway rides a separate cloudflared quick tunnel: random URL per run is fine
# (/connect generates commands live) and Tier-2 is a handful of one-shot calls,
# nothing like the room-scale admin-UI SSE that melted quick tunnels before.
if curl -s -m 3 localhost:4040/api/tunnels 2>/dev/null | grep -q "$DOMAIN"; then
  ok "ngrok tunnel already up"
else
  pkill -f 'ngrok' 2>/dev/null; sleep 1
  nohup ngrok http --url="$URL" 7070 --log stdout >"$NGROK_LOG" 2>&1 &
  for i in $(seq 1 15); do
    curl -s -m 2 localhost:4040/api/tunnels 2>/dev/null | grep -q "$DOMAIN" && break; sleep 1
  done
  if curl -s -m 2 localhost:4040/api/tunnels 2>/dev/null | grep -q "$DOMAIN"; then
    ok "ngrok tunnel established"
  else
    warn "ngrok tunnel NOT up (no internet? see $NGROK_LOG) — everything else still works on localhost; re-run when online"
  fi
fi

GW_TUNNEL_LOG=/tmp/cloudflared-gateway.log
if pgrep -f 'cloudflared tunnel --url http://localhost:4444' >/dev/null \
   && grep -qoE 'https://[a-z0-9-]+\.trycloudflare\.com' "$GW_TUNNEL_LOG" 2>/dev/null; then
  ok "gateway cloudflared tunnel already up"
else
  pkill -f 'cloudflared tunnel --url http://localhost:4444' 2>/dev/null; sleep 1
  : >"$GW_TUNNEL_LOG"
  nohup cloudflared tunnel --url http://localhost:4444 >"$GW_TUNNEL_LOG" 2>&1 &
  for i in $(seq 1 20); do
    grep -qoE 'https://[a-z0-9-]+\.trycloudflare\.com' "$GW_TUNNEL_LOG" 2>/dev/null && break; sleep 1
  done
fi
GATEWAY_PUBLIC_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$GW_TUNNEL_LOG" 2>/dev/null | head -1)
[ -n "$GATEWAY_PUBLIC_URL" ] && ok "gateway public URL: $GATEWAY_PUBLIC_URL" \
  || warn "no public gateway URL — /connect will be localhost-only (Tier-2 room laptops can't use it)"

step "5/6 companion :7070 (QR public URL + /connect gateway URL must both match)"
_connect_gw() {
  curl -sf -m 3 http://127.0.0.1:7070/api/connect 2>/dev/null | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('base', ''))
except Exception:
    pass" 2>/dev/null
}
if curl -sf -m 3 http://127.0.0.1:7070/qr 2>/dev/null | grep -q "$DOMAIN" \
   && { [ -z "$GATEWAY_PUBLIC_URL" ] || [ "$(_connect_gw)" = "$GATEWAY_PUBLIC_URL" ]; }; then
  ok "companion up — QR encodes $DOMAIN, /connect matches the gateway tunnel"
else
  # wrong/missing COMPANION_URL or stale GATEWAY_PUBLIC_URL both land here: restart it
  pkill -f 'companion/app.py' 2>/dev/null; sleep 1
  nohup env COMPANION_URL="$URL" GATEWAY_PUBLIC_URL="$GATEWAY_PUBLIC_URL" EXPOSE_CONNECT=1 \
    make companion >"$COMPANION_LOG" 2>&1 &
  for i in $(seq 1 20); do curl -sf -m 2 http://127.0.0.1:7070/ >/dev/null 2>&1 && break; sleep 1; done
  if curl -sf -m 3 http://127.0.0.1:7070/qr 2>/dev/null | grep -q "$DOMAIN"; then
    ok "companion started, QR encodes $DOMAIN"
    [ -n "$GATEWAY_PUBLIC_URL" ] && [ "$(_connect_gw)" = "$GATEWAY_PUBLIC_URL" ] \
      && ok "/connect serves the public gateway URL for Tier-2" \
      || warn "/connect gateway URL mismatch — check $COMPANION_LOG"
  else
    warn "companion up but QR does NOT show $DOMAIN — check $COMPANION_LOG"
  fi
fi

step "6/6 keep-awake + open the projector page"
pgrep -f 'caffeinate -dims' >/dev/null || { nohup caffeinate -dims >/dev/null 2>&1 & ok "caffeinate started"; }
open "http://127.0.0.1:7070/qr" 2>/dev/null || true

cat <<EOF

════════════════════════════════════════════════════════════════════
  PROJECT THIS   →  http://127.0.0.1:7070/qr
  YOUR VIEW      →  http://127.0.0.1:7070/follow.html   (and /wall)
  CLEAN COUNTER  →  make agents-reset   (once, before doors open)

  ⚠  NEVER open $URL
     in a browser ON THIS LAPTOP — Cisco Umbrella blocks it and it
     will look like an outage. Phones on cellular are fine.
════════════════════════════════════════════════════════════════════
EOF
