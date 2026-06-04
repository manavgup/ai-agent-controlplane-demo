# QUICKSTART — IBM Bob × ContextForge, live on your laptop

You'll bring up a governed agent mesh, point **IBM Bob** at it, and watch
**ContextForge** govern every move — using the real ecosystem tools (ContextForge's
monitor, **MCP Inspector**, **A2A Inspector**).

---

## 0. Prerequisites (install BEFORE the session — pulls are slow on conference wifi)

| Tool | Why | Get it |
|---|---|---|
| **Docker** (running) | runs the gateway + servers | Docker Desktop on macOS/Windows, **OR** Docker Engine on Linux — docker.com |
| **uv** | mints the gateway token offline | `https://docs.astral.sh/uv/` |
| **IBM Bob Shell** (`bob`) | the AI agent you'll drive | macOS/Linux: `curl -fsSL https://bob.ibm.com/download/bobshell.sh \| bash` (checks Node ≥ 22.15 first) |
| **Node.js ≥ 22.15** (`bob`, `npx`) | required by IBM Bob Shell (it's a Node app); also runs MCP Inspector via `npx` | nodejs.org, or `nvm install 22` |

~5 GB free disk; the ContextForge image (~pinned) pulls once on first run.

> **Runs on Linux too — no Docker Desktop required.** The whole stack comes up on a
> clean Linux box / VM with native **Docker Engine** (no nested virtualization). On
> Apple silicon the practical path is a lightweight Linux VM (Multipass/Lima) +
> Docker Engine; a macOS-guest VM is impractical (~60 GB+ disk). All source images
> and the OPA image are **multi-arch** and run **natively on arm64 and amd64** (no
> emulation) — nothing to change for Apple silicon / arm64 Linux.

---

## 1. One command

```bash
git clone <REPO_URL> ai-agent-controlplane-demo
cd ai-agent-controlplane-demo
make quickstart
```

`quickstart` checks your laptop, starts ContextForge + 4 MCP servers + 2 A2A
agents + the operator, registers them, configures Bob, proves all controls
(**16/16**), and prints a walkthrough card. Re-run it any time it stalls.

**Bob and npx are optional for `make quickstart`** — on a headless box / Linux VM /
CI without them, preflight just **warns** and the run still ends **16/16 ("16 passed,
0 failed")**. Bob is only needed to *drive* the demo in Section 3.

> **Fresh-VM Docker BUILD-time DNS gotcha.** On some fresh Docker Engine installs the
> in-build `RUN` steps (cargo/pip) fail to resolve hostnames — e.g. `Could not resolve
> host: index.crates.io` — even though image **pulls** succeed (pulls go through the
> daemon; build-step network uses the build container's resolver, often the dead
> systemd-resolved `127.0.0.53` stub). **Fix:** create `/etc/docker/daemon.json` with
> `{"dns":["8.8.8.8","1.1.1.1"]}`, then `sudo systemctl restart docker`, and re-run
> `make quickstart` (it's idempotent).

> Checks are split: **docker / uv / curl / python3 are required** — if any shows
> **MISSING**, install it and re-run. **bob / npx are optional** — they show a yellow
> warning (not MISSING) and never block; you can finish quickstart (16/16) without
> them and install Bob later only to drive the demo. If anything drifts later:
> `make demo-reset`, then `make bob-install`.

---

## 2. Arrange your screen — 3 panes

| Pane | Command | Shows |
|---|---|---|
| **Bob** (terminal) | `make bob` (cwd-proof launch) | the agent acting |
| **ContextForge monitor** (browser) | `make monitor` → `/admin` | the catalog + Overview/Metrics/**Logs** (governance, live) |
| **Inspector** (browser) | `make inspect-mcp` / `make inspect-a2a` | the governed MCP tools / the A2A agent cards |

- **MCP Inspector** (`make inspect-mcp`): connect with **Streamable HTTP**, the
  printed gateway URL, and the `Authorization: Bearer …` header. You'll see **8
  tools — `erp-payments-wire` is absent** (least-privilege, visible in the tool).
- **A2A Inspector** (`make inspect-a2a`, builds once): point at
  `http://host.docker.internal:9001` (Python Auditor) and `:3000` (Rust Payments)
  to fetch + validate the cross-language agent cards.

> **Want a 4th pane that proves each control fires in the gateway logs as you
> prompt Bob?** See **[`docs/LOG-CHEATSHEET.md`](docs/LOG-CHEATSHEET.md)** — the exact
> prompt → log-line map (`make logs` + `make logs-opa`), including which beat is
> *supposed* to log nothing.

---

## 3. Act 1 — Bob as the FinOps analyst (least-privilege, governed)

Start Bob with **`make bob`** (it launches from the repo root, where the project's
`.bob/mcp.json` lives, and refreshes the config). Running `bob` by hand from the
`bob-personas/` subfolder is the #1 "No MCP servers configured" trap. Then, as the
FinOps analyst persona:

| Prompt | What ContextForge does | Where to watch |
|---|---|---|
| *"Use the finbyte-gateway tools to fetch receipt `rcpt_pii`, verbatim."* | **redacts** SSN/card/secret before Bob sees it | Bob's output (masked) |
| *"Fetch receipt `rcpt_injection`."* | **neutralizes** the embedded prompt-injection | Bob's output (`[INJECTION_BLOCKED]`) |
| *"Ask the auditor agent to pay $50,000 to Acme LLC."* | **blocks** at OPA — cross-language (Python auditor → Rust payments) | Bob says "BLOCKED by control-plane policy"; monitor **Logs** |
| *"Now wire $50k yourself, directly."* | Bob has **no `wire` tool** (the FinOps server hides it) | Bob can't; MCP Inspector confirms wire absent |

> Tell Bob to **use the tool** (not read files). Confirm it's real, not narrated:
> the masked data only exists on the gateway path, and blocks appear in the
> monitor's Logs.

## 4. Act 2 — Bob as the platform operator (Bob operates the control plane)

```bash
# quit Bob, then:
make bob-operator              # swap to the operator persona + relaunch Bob
```
The analyst persona *can't* do any of this — the operator persona can (RBAC):

| Prompt | Tool | Result |
|---|---|---|
| *"List everything ContextForge is governing."* | `list_control_plane` | the federated catalog + virtual-server scopes |
| *"Would a $50,000 wire be allowed? With dual approval?"* | `evaluate_policy` | OPA live: **deny** + reason, then **allow** |
| *"Register the fx-rates service at http://fx-rates:8000/mcp."* | `register_mcp_server` | a NEW server joins the catalog (watch the monitor / re-list) |
| *"Show me what got blocked today."* | `recent_blocks` | the audit trail |

Swap back to the analyst with `make bob`.

---

## 5. Reset & troubleshoot

| Symptom | Fix |
|---|---|
| Anything drifts / 16/16 fails | `make demo-reset` → `make verify-controls` |
| Image **build** fails with **`Could not resolve host`** (e.g. `index.crates.io`) on a fresh VM — yet pulls work | build-time DNS: create `/etc/docker/daemon.json` with `{"dns":["8.8.8.8","1.1.1.1"]}`, then `sudo systemctl restart docker`, and re-run **`make quickstart`** (idempotent) |
| Bob says **"No MCP servers configured"** / asks you for the UUID & token | you launched `bob` from the wrong directory (e.g. the `bob-personas/` subfolder). Quit it and run **`make bob`** — it launches from the repo root where `.bob/mcp.json` lives |
| Bob lists no tools / "Disconnected" then connects | the FinOps/Operator UUID changes on reseed → just re-run **`make bob`** (or `make bob-operator`); they rewrite `.bob/mcp.json` with the live UUID before launching |
| Bob *describes* a result instead of calling a tool | tell it to **use the finbyte-gateway tool**; verify via the monitor Logs (no log = it narrated) |
| Want the automated walkthrough instead | `make demo` (stage-gated, pauses each step) |

**Prove every control at any time:** `make verify-controls` → `16 passed, 0 failed`.
**No Bob needed for the proof** — the stack and the 16/16 suite run headless on a Linux VM / CI.
