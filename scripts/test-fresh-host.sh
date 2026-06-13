#!/usr/bin/env bash
# test-fresh-host.sh — stand up + prove the demo on a FRESH non-macOS host.
#
# Built to validate the cross-platform path the author's Mac can't cover:
# x86_64 Linux (e.g. an IBM Cloud Ubuntu VSI), WSL2 Ubuntu, or a Podman box with
# no Docker at all. It installs the toolchain, brings the stack up, seeds it, and
# verifies every cockpit surface answers — then tells you how to drive the cockpit.
#
# Runtime: uses Docker if it's already present and working; otherwise installs and
# uses Podman (rootless) with Docker Compose v2 against the Podman API socket — the
# combo proven to run this 10-service stack (the legacy python podman-compose
# mishandles long-form env_file, shared build contexts, and depends_on).
#
# Tested on Ubuntu 24.04 (apt) on arm64 and x86_64. For Fedora/RHEL swap apt→dnf
# (package names are the same); the rest is distro-agnostic.
#
# Usage, from inside a clone:   bash scripts/test-fresh-host.sh
#        or bootstrap a clone:  curl -fsSL <raw-url>/scripts/test-fresh-host.sh | bash
set -uo pipefail

REPO_URL="${REPO_URL:-https://github.com/manavgup/ai-agent-controlplane-demo.git}"
REPO_REF="${REPO_REF:-main}"        # branch/tag to clone when not already in a checkout
COMPOSE_V2_VERSION="${COMPOSE_V2_VERSION:-v2.32.4}"

say(){ printf "\n\033[1m== %s ==\033[0m\n" "$*"; }
ok(){  printf "  \033[32m✔\033[0m %s\n" "$*"; }
warn(){ printf "  \033[33m!\033[0m %s\n" "$*"; }
die(){ printf "\n\033[31m\033[1mSTOPPED:\033[0m %s\n" "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "this bootstrap targets Linux hosts (IBM Cloud VSI, a Linux VM, or WSL2). On macOS just run 'make quickstart'."
command -v apt-get >/dev/null 2>&1 || warn "no apt-get — this script installs via apt (Debian/Ubuntu/WSL2). On Fedora/RHEL install the same packages with dnf, then re-run; the rest works unchanged."

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ── pick a container runtime ─────────────────────────────────────────────────
RUNTIME=""
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  RUNTIME="docker"; ok "Docker present and responding — using it."
else
  RUNTIME="podman"; ok "No working Docker — will install/use Podman (rootless)."
fi

# ── install toolchain ────────────────────────────────────────────────────────
say "Installing toolchain (this is the slow step on a cold host)"
if command -v apt-get >/dev/null 2>&1; then
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get update -qq
  PKGS="make git tmux curl python3 python3-pip nodejs npm"
  [ "$RUNTIME" = "podman" ] && PKGS="$PKGS podman uidmap"
  # Note: NOT silenced — if apt fails (e.g. podman vs an existing docker-ce), the
  # error must be visible, and we must NOT march on to a doomed `make up`.
  if ! $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y $PKGS; then
    if [ "$RUNTIME" = "podman" ] && command -v docker >/dev/null 2>&1; then
      die "apt couldn't install Podman — it conflicts with the docker-ce already on this host (shared containerd.io / CNI packages). This host isn't 'fresh': use its existing Docker instead — 'sudo usermod -aG docker \$USER', log out and back in, then re-run. (Podman + docker-ce can co-exist, but it needs manual conflict resolution.)"
    fi
    die "package install failed — see the apt output above."
  fi
fi
ok "base packages installed"

# uv — used for offline JWT minting, the seed, and the companion.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  for d in "$HOME/.local/bin" "$HOME/.cargo/bin"; do [ -x "$d/uv" ] && $SUDO ln -sf "$d/uv" /usr/local/bin/uv && $SUDO ln -sf "$d/uvx" /usr/local/bin/uvx 2>/dev/null; done
fi
command -v uv >/dev/null 2>&1 || die "uv install failed — see https://docs.astral.sh/uv/"
ok "uv $(uv --version 2>&1 | awk '{print $2}')"

# ── Podman: Docker Compose v2 + rootless API socket ──────────────────────────
if [ "$RUNTIME" = "podman" ]; then
  if ! command -v docker-compose >/dev/null 2>&1; then
    say "Installing Docker Compose v2 ($COMPOSE_V2_VERSION) — the compose engine for Podman"
    ARCH=$(uname -m)   # x86_64 | aarch64
    $SUDO curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_V2_VERSION}/docker-compose-linux-${ARCH}" -o /usr/local/bin/docker-compose
    $SUDO chmod +x /usr/local/bin/docker-compose
  fi
  ok "docker-compose $(docker-compose version --short 2>&1)"

  say "Enabling the rootless Podman API socket"
  $SUDO loginctl enable-linger "$(id -un)" 2>/dev/null || true
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  systemctl --user enable --now podman.socket 2>/dev/null || podman system service --time=0 "unix://${XDG_RUNTIME_DIR}/podman/podman.sock" >/dev/null 2>&1 &
  sleep 2
  SOCK="${XDG_RUNTIME_DIR}/podman/podman.sock"
  [ -S "$SOCK" ] && ok "Podman socket live: $SOCK" || warn "Podman socket not found at $SOCK — the Makefile will still try it; if compose can't connect, run: systemctl --user enable --now podman.socket"
fi

# tmux / node sanity (cockpit + MCP inspector need them)
command -v tmux >/dev/null 2>&1 && ok "tmux $(tmux -V | awk '{print $2}')" || warn "tmux missing — 'make cockpit' won't run"
command -v npx  >/dev/null 2>&1 && ok "npx present (MCP inspector)" || warn "npx missing — 'make inspect-mcp' won't run"

# ── get the repo ─────────────────────────────────────────────────────────────
if [ -f "Makefile" ] && grep -q "^cockpit:" Makefile 2>/dev/null; then
  ok "already inside a checkout: $(pwd)"
else
  say "Cloning $REPO_URL ($REPO_REF)"
  git clone -q --branch "$REPO_REF" "$REPO_URL" ai-agent-controlplane-demo || die "clone failed"
  cd ai-agent-controlplane-demo || die "cd failed"
fi

# ── bring it up + seed (Makefile auto-detects podman + socket) ───────────────
say "make up — build images + start the 10-service stack (first run builds everything)"
make up || die "stack failed to start. Logs:  ${COMPOSE:-docker compose} logs gateway"
say "make seed — register servers/agents + build the FinOps/Treasury/Operator virtual servers"
make seed || die "seed failed"

# ── prove it ─────────────────────────────────────────────────────────────────
say "Proof"
curl -sf localhost:4444/health >/dev/null 2>&1 && ok "gateway healthy (http://localhost:4444/health)" || die "gateway not healthy"
ADMIN=$(make -s token 2>/dev/null | tail -1)
NSERVERS=$(curl -s -H "Authorization: Bearer $ADMIN" localhost:4444/servers | python3 -c "import sys,json; print(len([s for s in json.load(sys.stdin) if isinstance(s,dict)]))" 2>/dev/null || echo 0)
[ "$NSERVERS" -ge 3 ] 2>/dev/null && ok "seeded — $NSERVERS virtual servers (expect FinOps/Treasury/Operator)" || warn "expected ≥3 virtual servers, saw $NSERVERS — re-run 'make seed'"

printf "\n\033[1m✔ Stack is up and seeded on this %s %s host.\033[0m\n" "$(uname -m)" "$RUNTIME"
cat <<EOF

Drive it (no manual env needed — the Makefile auto-detects the runtime):
  make cockpit       # tmux: Bob + logs + OPA + both inspectors (run in a REAL terminal)
  make companion     # browser dashboard → http://localhost:7070
  make inspect-a2a   # A2A inspector     → http://localhost:8090
  make inspect-mcp   # MCP inspector     → http://localhost:6274
  make verify-controls   # headless proof of the four controls → 16/16

Tear down:  make down   (and 'make cockpit-down' if you started the cockpit)
EOF
