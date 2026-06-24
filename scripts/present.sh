#!/usr/bin/env bash
# present.sh — `make present`: ONE command to run the room-facing demo.
#
# Starts public cloudflared quick-tunnels for the Companion (:7070) and the
# ContextForge gateway (:4444), runs the Companion pointed at those public URLs,
# opens the dashboard/QR in your browser, and serves the join QR. This sidesteps
# GitHub Codespaces forwarded ports, which 404 anonymous clients (a phone with no
# GitHub login) — cloudflared gives a genuinely public https URL that any phone
# reaches. Works the same on a local laptop (no Codespace needed).
#
# Quick-tunnel URLs are RANDOM and change every run — that's fine: the QR is
# generated live from the current URL, nothing is hardcoded. Ctrl-C stops the
# Companion and tears down both tunnels.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$(tput bold 2>/dev/null); D=$(tput dim 2>/dev/null); R=$(tput sgr0 2>/dev/null)
  GRN=$(tput setaf 2 2>/dev/null); YEL=$(tput setaf 3 2>/dev/null); CYN=$(tput setaf 6 2>/dev/null)
else B=; D=; R=; GRN=; YEL=; CYN=; fi
say(){ printf "  ${GRN}✔${R} %s\n" "$*"; }
warn(){ printf "  ${YEL}!${R} %s\n" "$*"; }

# ── 1) cloudflared (download the static binary if it's missing) ───────────────
CF=$(command -v cloudflared 2>/dev/null || true)
if [ -z "$CF" ] && [ -x "$HOME/cloudflared" ]; then CF="$HOME/cloudflared"; fi
if [ -z "$CF" ]; then
  printf "${B}Installing cloudflared…${R}\n"
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$(uname -m)" in x86_64|amd64) arch=amd64;; arm64|aarch64) arch=arm64;; *) arch=amd64;; esac
  if curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${os}-${arch}" -o "$HOME/cloudflared"; then
    chmod +x "$HOME/cloudflared"; CF="$HOME/cloudflared"
  else
    echo "could not download cloudflared — install it manually: https://github.com/cloudflare/cloudflared"; exit 1
  fi
fi
say "cloudflared: $("$CF" --version 2>&1 | head -1)"

# ── 2) the mesh must be up (the Companion brokers to it) ──────────────────────
if ! curl -sf -o /dev/null http://localhost:4444/health; then
  echo "gateway not up at localhost:4444 — run '${B}make up && make seed${R}' first."; exit 1
fi
make --no-print-directory salestax-ensure >/dev/null 2>&1 || true

# ── 3) start the two tunnels, capture the random https URLs ───────────────────
TUNNEL_PIDS=""
start_tunnel(){ # $1=port  $2=logfile  → echoes the https URL, records the pid
  pkill -f "cloudflared tunnel --url http://localhost:$1" 2>/dev/null || true
  : > "$2"
  nohup "$CF" tunnel --url "http://localhost:$1" >"$2" 2>&1 &
  TUNNEL_PIDS="$TUNNEL_PIDS $!"
  for _ in $(seq 1 40); do
    u=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$2" 2>/dev/null | head -1)
    [ -n "$u" ] && { printf '%s' "$u"; return 0; }
    sleep 1
  done
  return 1
}
printf "${B}Opening public tunnels (this takes a few seconds)…${R}\n"
CF7070=$(start_tunnel 7070 /tmp/present-cf7070.log) || { echo "companion tunnel failed — see /tmp/present-cf7070.log"; exit 1; }
say "companion tunnel: $CF7070"
CF4444=$(start_tunnel 4444 /tmp/present-cf4444.log) || { echo "gateway tunnel failed — see /tmp/present-cf4444.log"; exit 1; }
say "gateway tunnel:   $CF4444"

# tear the tunnels down when the Companion exits (Ctrl-C). Kill by recorded pid
# (robust — the tunnels are backgrounded so they don't get the terminal's SIGINT)
# plus a pkill fallback.
cleanup(){
  # shellcheck disable=SC2086
  [ -n "$TUNNEL_PIDS" ] && kill $TUNNEL_PIDS 2>/dev/null || true
  pkill -f "cloudflared tunnel --url http://localhost:7070" 2>/dev/null || true
  pkill -f "cloudflared tunnel --url http://localhost:4444" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── 4) the banner + open the presenter's browser to the QR ────────────────────
QR_URL="$CF7070/qr"
cat <<EOF

${B}════════════════════════════════════════════════════════════════${R}
 ${B}PROJECT THIS for the room (scan to join — no install):${R}
   ${CYN}$QR_URL${R}
 ${D}Phone/laptop dashboard:${R} ${CYN}$CF7070${R}
 ${D}Bob (Tier-2) gateway:${R}  ${CYN}$CF4444${R}   ${D}— the /connect page hands this out${R}
${B}════════════════════════════════════════════════════════════════${R}
 ${D}Ctrl-C stops the Companion and closes both tunnels.${R}

EOF
# open the QR in the presenter's browser once the Companion is serving
( sleep 7
  if command -v open >/dev/null 2>&1; then open "$QR_URL"
  elif [ -n "${BROWSER:-}" ]; then "$BROWSER" "$QR_URL"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$QR_URL"
  else printf "  ${YEL}!${R} open this yourself: %s\n" "$QR_URL"; fi ) >/dev/null 2>&1 &

# ── 5) run the Companion pointed at the tunnels (foreground; Ctrl-C ends it) ───
COMPANION_URL="$CF7070" GATEWAY_PUBLIC_URL="$CF4444" EXPOSE_CONNECT=1 \
  make --no-print-directory companion
