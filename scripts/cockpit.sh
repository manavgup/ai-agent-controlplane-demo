#!/usr/bin/env bash
# cockpit.sh — `make cockpit`: a tmux multi-pane control-plane "cockpit".
#
# Tiles the interactive Bob session (big left pane) alongside the live watch
# surfaces (gateway logs, OPA decisions, MCP Inspector, A2A Inspector) so an
# advanced user/presenter sees the whole control plane in one window with one
# command. Pure orchestration: every pane runs an existing `make <target>`, so
# all token-minting / UUID-lookup / log logic is reused, not duplicated.
#
# Two modes, keyed on $TMUX:
#   cold start (not in tmux) → build the `cockpit` session, attach.
#   augment   (in tmux)      → split the watch panes off the ACTIVE pane (run it
#                              from your Bob pane); records created pane ids in
#                              the @cockpit_panes session option for teardown.
#
# Persona: COCKPIT_PERSONA=operator swaps the Bob pane to `make bob-operator`
# (default: analyst → `make bob`).
#
# Tear down with:  make cockpit-down
#
# Usage:  make cockpit   (or: bash scripts/cockpit.sh)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# ── colours (only when attached to a TTY) ───────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$(tput bold 2>/dev/null); D=$(tput dim 2>/dev/null); R=$(tput sgr0 2>/dev/null)
  RED=$(tput setaf 1 2>/dev/null); GRN=$(tput setaf 2 2>/dev/null)
  YEL=$(tput setaf 3 2>/dev/null); CYN=$(tput setaf 6 2>/dev/null)
else B=; D=; R=; RED=; GRN=; YEL=; CYN=; fi

ok(){   printf "  ${GRN}✔${R} %s\n" "$*"; }
warn(){ printf "  ${YEL}!${R} %s\n" "$*"; }
die(){  printf "\n${RED}${B}STOPPED:${R} %s\n" "$*" >&2; exit 1; }
hd(){   echo; printf "${B}== %s ==${R}\n" "$*"; }

GW="http://localhost:4444"
SECRET="${SECRET:-demo-only-change-me-0123456789abcdef}"
MINT_CMD=(env DATABASE_URL=sqlite:///./.tokmint.db uv run --with mcp-contextforge-gateway -- \
  python -m mcpgateway.utils.create_jwt_token)

# Bob persona → which make target hosts the Bob pane.
PERSONA="${COCKPIT_PERSONA:-analyst}"
case "$PERSONA" in
  operator) BOB_TARGET="bob-operator" ;;
  analyst)  BOB_TARGET="bob" ;;
  *) die "COCKPIT_PERSONA must be 'analyst' or 'operator' (got '$PERSONA')." ;;
esac

# Inspector ports (for the SSH port-forward hint).
MCP_INSPECTOR_PORT=6274        # @modelcontextprotocol/inspector default client UI
MCP_INSPECTOR_PROXY_PORT=6277  # its proxy/API — the 6274 UI calls this; forward both or the UI loads but can't connect
A2A_INSPECTOR_PORT=8090        # `make inspect-a2a` publishes the container on :8090

SESSION="cockpit"

# ── preflight 1: tmux present? ───────────────────────────────────────────────
if ! command -v tmux >/dev/null 2>&1; then
  hd "tmux not found"
  cat <<EOF
  The cockpit needs tmux. Install it:
    macOS:  ${CYN}brew install tmux${R}
    Linux:  ${CYN}sudo apt-get install tmux${R}  (or your distro's package manager)

  Until then, open these in separate terminals/tabs by hand:
    ${CYN}make ${BOB_TARGET}${R}       — drive Bob
    ${CYN}make logs${R}        — gateway log tail
    ${CYN}make logs-opa${R}    — OPA ALLOW/DENY decisions
    ${CYN}make inspect-mcp${R} — MCP Inspector (the 8 governed tools)
    ${CYN}make inspect-a2a${R} — A2A Inspector (the agent cards)
    ${CYN}make monitor${R}     — ContextForge Admin UI
EOF
  exit 0
fi

# ── preflight 2: gateway healthy? ────────────────────────────────────────────
if ! curl -sf "$GW/health" >/dev/null 2>&1; then
  die "Stack isn't up — run ${CYN}make quickstart${R} first."
fi
ok "gateway healthy ($GW)"

# ── preflight 3: stack SEEDED? (FinOps virtual server exists) ─────────────────
# Reuse the Makefile's MINT pattern: mint an admin token, look up the FinOps
# server by name (same lookup inspect-mcp / companion use).
ADMIN=$("${MINT_CMD[@]}" -u admin@finbyte.demo --admin -e 10080 -s "$SECRET" 2>/dev/null | tail -1)
if [ -z "$ADMIN" ]; then
  die "couldn't mint an admin token — is ${CYN}uv${R} installed? (the stack is up but token minting failed)"
fi
FINOPS=$(curl -s -H "Authorization: Bearer $ADMIN" "$GW/servers" \
  | python3 -c "import sys,json;[print(s['id']) for s in json.load(sys.stdin) if isinstance(s,dict) and s.get('name')=='FinOps']" 2>/dev/null | head -1)
if [ -z "$FINOPS" ]; then
  die "Gateway is up but not seeded — run ${CYN}make seed${R} (or ${CYN}make quickstart${R})."
fi
ok "stack seeded (FinOps server $FINOPS)"

# ── preflight 4: optional dependency probes (warn, never fatal) ───────────────
# Advisory: tell the user up front which panes will fail. A failing pane shows
# its error and waits for Enter before closing (see pane_cmd), so nothing is lost.
probe(){ command -v "$1" >/dev/null 2>&1 || warn "$1 not found — the '$2' pane will error out (shows the message, closes on Enter)"; }
probe npx     "inspect-mcp"
probe docker  "inspect-a2a"
probe git     "inspect-a2a (first-run build)"
probe python3 "logs-opa"
probe bob     "bob ($BOB_TARGET)"

# ── preflight 5: TTY + size guard ────────────────────────────────────────────
if [ ! -t 1 ]; then
  die "run from an interactive terminal (no TTY detected — the cockpit attaches a tmux session)."
fi
# tput may fail under TERM=dumb / non-terminal stdout; fall back to a roomy default.
COLS=$(tput cols 2>/dev/null); ROWS=$(tput lines 2>/dev/null)
case "$COLS" in ''|*[!0-9]*) COLS=200 ;; esac
case "$ROWS" in ''|*[!0-9]*) ROWS=50  ;; esac
[ "$COLS" -ge 1 ] 2>/dev/null || COLS=200
[ "$ROWS" -ge 1 ] 2>/dev/null || ROWS=50
if [ "$COLS" -lt 120 ] || [ "$ROWS" -lt 32 ]; then
  warn "terminal is ${COLS}x${ROWS} — maximize your terminal, 5 panes need room (>=120x32)."
fi

# ── SSH-aware URL / browser handling ─────────────────────────────────────────
# The cockpit (tmux) works over SSH, but the browser surfaces live on the REMOTE
# host. Over SSH (or with no opener) print URLs + a port-forward hint instead of
# claiming a tab opened. Locally, reuse the `open || xdg-open` pattern.
have_opener(){ command -v open >/dev/null 2>&1 || command -v xdg-open >/dev/null 2>&1; }
open_admin(){
  if [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ] || ! have_opener; then
    cat <<EOF

  ${B}Remote session detected${R} — these UIs are on the remote host. Forward them:
    ${CYN}ssh -L 4444:localhost:4444 -L ${MCP_INSPECTOR_PORT}:localhost:${MCP_INSPECTOR_PORT} -L ${MCP_INSPECTOR_PROXY_PORT}:localhost:${MCP_INSPECTOR_PROXY_PORT} -L ${A2A_INSPECTOR_PORT}:localhost:${A2A_INSPECTOR_PORT} <host>${R}
  Then open:
    Admin UI       : http://localhost:4444/admin
    MCP Inspector  : http://localhost:${MCP_INSPECTOR_PORT}
    A2A Inspector  : http://localhost:${A2A_INSPECTOR_PORT}
EOF
  else
    echo "  Opening ContextForge Admin UI → $GW/admin"
    (open "$GW/admin" 2>/dev/null || xdg-open "$GW/admin" 2>/dev/null || true)
  fi
}

# The four stacked watch panes, top-to-bottom.
WATCH_TARGETS=(logs logs-opa inspect-mcp inspect-a2a)

# Build the command a pane runs. On a CLEAN exit the pane closes (no lingering
# "dead" pane to kill by hand); on an ERROR it holds the message until Enter so a
# missing-dep failure stays readable. This replaces a window-wide
# `remain-on-exit on`, which turned every normal exit into a dead pane the user
# had to kill manually (and, in augment mode, polluted their real window).
pane_cmd(){ echo "make $1 || { echo; echo '[$1 exited - scroll up to read; press Enter to close]'; read _; }; exit"; }

teardown_hint(){ printf "\n  %sto tear down:%s %smake cockpit-down%s\n" "$D" "$R" "$CYN" "$R"; }

# ── COLD START (not in tmux): build the session, attach ──────────────────────
cold_start(){
  # Re-run collision: a cockpit session already exists → attach to it.
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    warn "cockpit already running — attaching; ${CYN}make cockpit-down${R} first for a fresh layout."
    teardown_hint
    open_admin
    exec tmux attach -t "$SESSION"
  fi

  hd "Building the cockpit (Bob + 4 watch panes)"
  # Create detached WITH explicit geometry — a detached session otherwise
  # defaults to 80x24 and the percentage splits come out wrong.
  tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS"

  # Layout. split-window -p is relative to the target pane AT SPLIT TIME, so
  # order matters. We capture each pane's id (-P -F '#{pane_id}') rather than
  # assuming index 0 — the user's tmux may set base-index/pane-base-index to 1,
  # so hardcoded :0.0 targets don't exist. The geometry is identical: Bob keeps
  # the left ~62%, the right column splits into four ~25% stacked panes.
  local bob right p2 p3 p4
  bob=$(tmux list-panes -t "$SESSION" -F '#{pane_id}' | head -1)   # the lone initial pane = Bob
  right=$(tmux split-window -h -p 38 -t "$bob"   -P -F '#{pane_id}')  # right column, 38% width
  p2=$(tmux    split-window -v -p 75 -t "$right" -P -F '#{pane_id}')  # right ≈ top 25%
  p3=$(tmux    split-window -v -p 67 -t "$p2"    -P -F '#{pane_id}')  # ≈ next 25%
  p4=$(tmux    split-window -v -p 50 -t "$p3"    -P -F '#{pane_id}')  # last two ≈ 25% each

  # Send each pane its command. Bob in the big left pane; the four watch panes
  # top-to-bottom down the right column.
  tmux send-keys -t "$bob" "$(pane_cmd "$BOB_TARGET")" Enter
  local watch_panes=("$right" "$p2" "$p3" "$p4") i=0
  for t in "${WATCH_TARGETS[@]}"; do
    tmux send-keys -t "${watch_panes[$i]}" "$(pane_cmd "$t")" Enter
    i=$((i + 1))
  done

  ok "cockpit session built — Bob persona: $PERSONA"
  teardown_hint
  open_admin
  exec tmux attach -t "$SESSION"
}

# ── AUGMENT (already in tmux): split watch panes off the active pane ──────────
augment(){
  hd "Augmenting the current tmux window with the watch panes"
  warn "augment tiles around the ACTIVE pane — run this from your Bob pane (it does not start a second Bob)."

  local anchor created=()
  anchor=$(tmux display-message -p '#{pane_id}')

  # First split halves the anchor pane width; then stack the four watch panes
  # in that new column. pane_cmd closes each pane cleanly on exit (no dead panes
  # left in the user's real window) and holds only on error.
  local pane
  pane=$(tmux split-window -h -t "$anchor" -P -F '#{pane_id}' "$(pane_cmd "${WATCH_TARGETS[0]}")")
  created+=("$pane")
  local prev="$pane" idx
  for idx in 1 2 3; do
    pane=$(tmux split-window -v -t "$prev" -P -F '#{pane_id}' "$(pane_cmd "${WATCH_TARGETS[$idx]}")")
    created+=("$pane")
    prev="$pane"
  done

  # Even out the four stacked panes.
  tmux select-layout -E >/dev/null 2>&1 || true

  # Record exactly the panes we created so cockpit-down can kill only these.
  tmux set-option @cockpit_panes "${created[*]}" >/dev/null

  ok "added ${#created[@]} watch panes (${created[*]})"
  teardown_hint
  open_admin
}

if [ -z "${TMUX:-}" ]; then
  cold_start
else
  augment
fi
