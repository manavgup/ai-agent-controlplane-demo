#!/usr/bin/env bash
# follow-link.sh — `make follow-link`: print the ONE link to hand the room so
# Tier-1 attendees (phone or laptop, no install) get the live "Run it" dashboard
# wired straight into the follow-along page. It combines the STABLE GitHub Pages
# follow.html with `?dash=<live Companion URL>`; follow.html turns that into the
# "▶ Run it live" button. Pairs with `make companion` (the dashboard on :7070).
#
# Companion URL resolution (first hit wins), mirroring scripts/connect.sh:
#   COMPANION_URL=...   explicit (a presenter VM, a tunnel, anything)
#   $CODESPACE_NAME     auto: https://<codespace>-7070.<forwarding-domain>
#   else                http://localhost:7070  (same-machine only)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$(tput bold 2>/dev/null); D=$(tput dim 2>/dev/null); R=$(tput sgr0 2>/dev/null)
  GRN=$(tput setaf 2 2>/dev/null); YEL=$(tput setaf 3 2>/dev/null); CYN=$(tput setaf 6 2>/dev/null)
else B=; D=; R=; GRN=; YEL=; CYN=; fi
warn(){ printf "  ${YEL}!${R} %s\n" "$*"; }

# Where is the Companion (port 7070)?
if [ -n "${COMPANION_URL:-}" ]; then
  DASH="${COMPANION_URL%/}"; WHERE="COMPANION_URL override"
elif [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
  DASH="https://${CODESPACE_NAME}-7070.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; WHERE="GitHub Codespace"
else
  DASH="http://localhost:7070"; WHERE="localhost (same machine only — set COMPANION_URL or run in a Codespace for a room)"
fi

# The Companion now SERVES follow.html itself, so the whole attendee flow lives on
# ONE public port (:7070) — no GitHub Pages needed. Override FOLLOW_BASE to point at
# a hosted Pages copy instead (e.g. for a static printed-slide QR).
FOLLOW_BASE="${FOLLOW_BASE:-${DASH}/follow.html}"

# These Companion URLs contain no '&' or '#', so they survive as a query value
# unencoded and stay readable/copyable. URLSearchParams in follow.html decodes it.
LINK="${FOLLOW_BASE}?dash=${DASH}"

printf "\n${B}Companion (live dashboard):${R} %s   ${D}(%s)${R}\n" "$DASH" "$WHERE"
printf "\n${B}Hand THIS to the room (Tier 1 — watch + run the scenarios, no install):${R}\n"
printf "  ${CYN}%s${R}\n\n" "$LINK"
echo "  → opens the follow-along page with the '▶ Run it live' button pointed at your dashboard."
printf "\n${B}Easiest — project the ready-made QR${R} (attendees scan it off the screen):\n"
printf "  ${CYN}%s/qr${R}\n" "$DASH"
echo "  ${D}(open that in a browser tab, full-screen it — it encodes the link above. Re-run after any restart.)${R}"

case "$DASH" in
  https://*app.github.dev*)
    if curl -sf "$DASH/" >/dev/null 2>&1; then printf "  ${GRN}✔${R} dashboard reachable — attendees can run scenarios\n"
    else warn "port 7070 isn't public yet. In the Codespace PORTS tab set 7070 → ${B}Public${R}, run '${B}make companion${R}', then re-run this."; fi ;;
  http://localhost:*)
    warn "this is a LOCAL url — only this machine can reach it. For a room, run in a Codespace (7070 Public) or set COMPANION_URL=." ;;
esac
echo
