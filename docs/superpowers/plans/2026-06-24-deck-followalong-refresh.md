# Deck follow-along refresh — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the talk deck so its follow-along content matches the merged 3-tier experience — add one live "the room builds agents" slide to Part A and rewrite Part B (slides 14–20) into a tier-based appendix — then regenerate `slides/bob-controlplane-talk.pptx`.

**Architecture:** `slides/outline.md` is the source of truth; `slides/build_deck.py` hand-codes each slide sequentially with helpers (`add_slide`, `bg`, `stage_header`, `kicker`, `title_on_light`, `textbox`, `code_panel`, `rounded`, `accent_bar`, `notes`, `footer`) and renders the `.pptx` via python-pptx. We insert one slide in Part A (shifting later footers +1, `TOTAL` 20→21) and replace the seven Part B slide blocks.

**Tech Stack:** Python + python-pptx 1.0.2, run via `uv run --with python-pptx==1.0.2 python slides/build_deck.py`.

## Spec
`docs/superpowers/specs/2026-06-24-deck-followalong-refresh-design.md`

## Tasks run top-to-bottom in this order
Part B is rewritten to footers **15–21 first** (so the old 14–20 are gone), THEN Part A footers 7–13 are renumbered to 8–14 (no collision, since 14 is now free), THEN the new participation slide is inserted as footer 7. This keeps every `footer(s, N, …)` line unique at edit time.

## Conventions to reuse (from build_deck.py)
- `textbox(slide, x, y, w, h, runs, align=, anchor=, line_spacing=, space_after=)` — `runs` = list of paragraphs; each paragraph = list of run-tuples `(text, size, color, bold[, font][, italic])`.
- `code_panel(slide, x, y, w, h, lines, size=14, title=None, title_color=None)` — `lines` = list of `(text, color|None)`.
- `rounded(slide, x, y, w, h, fill, line=None, line_w=)`, `accent_bar(slide, x, y, w, h, color)`.
- `stage_header(slide, num, kick, title, danger=None, num_color=)` for ①②③④ light slides; `kicker()` + `title_on_light()` for other light slides.
- `notes(slide, "...")`; `footer(slide, idx, TOTAL, dark=False)`.
- Colors: `IBM_BLUE, INK, DARK_BG, PANEL, PANEL_LINE, WHITE, MUTE, GREEN, RED, CODE_BG, CODE_FG, GOLD, MINT, SKY`. Fonts: `FONT_HEAD, FONT_BODY, FONT_MONO`. `MSO_ANCHOR`, `PP_ALIGN`, `RGBColor` are already imported.
- Canonical drive prompts (use verbatim, from `docs/assets/prompts.json`):
  - `Use the finbyte-gateway tools to fetch receipt rcpt_pii, verbatim.`
  - `Use the finbyte-gateway tools to fetch receipt rcpt_injection, verbatim.`
  - `Ask the auditor agent to pay $50,000 to Acme LLC.`

## Slide-number end state
Part A: 1–6 unchanged · **7 = NEW participation slide** · 8–14 = old 7–13 (personas→takeaways). Part B: **15–21** (chooser, T1, T2, T3a, T3b, watch, troubleshooting). `TOTAL = 21`.

---

### Task 1: Update `slides/outline.md` (source of truth)

**Files:** Modify `slides/outline.md`

- [ ] **Step 1: Edit the Part A list** — after the "② Govern" bullet (item 6), insert:

```markdown
6b. **Now the room builds agents (live)** — Bob just registered the sales-tax
    server; now the room does too. Attendees scan the on-screen QR, name an agent
    with their initials, and register it — the projected `/wall` count climbs
    0 → N, live. The abstract `register` step becomes a shared moment. (QR is
    projected live from the companion's `/qr`; nothing baked into the slide.)
```

- [ ] **Step 2: Replace the entire "## Part B — Follow-Along Appendix" section** (items 14–20) with:

```markdown
## Part B — Follow-Along Appendix (~7 slides), run LIVE

14. **3 ways to take part (chooser)** — 👀 phone (no install) · 🧪 laptop Bob ·
    💻 full local. Mirrors `docs/follow.html`. Presenter setup (`make present` →
    cloudflared public tunnel; GitHub Codespaces public ports 404 anonymous
    clients) lives in the speaker notes.
15. **T1 📱 Phone** — scan the QR → follow-along page → run the three governed
    scenarios (PII redacted / injection neutralised / $50k blocked). No install.
16. **T2 🧪 Laptop Bob** — install Bob → dashboard's 🔌 Connect Bob → copy the
    command / download settings.json / one-liner (no token typing) → drive the
    three canonical prompts → governed. Same cloud control plane.
17. **T3 💻 Full local — build & govern** — `make quickstart` (finished, 16/16) or
    walk ① `make stage1-build` (→108.50 ungoverned) → ② register→grant→call
    (→108.50 governed).
18. **T3 💻 Full local — controls + proof** — `make stage3-controls` + the three
    analyst prompts + `make verify-controls` → 16 passed, 0 failed.
19. **Watch the control plane** — `make monitor` / `make inspect-mcp` /
    `make inspect-a2a` (or `make cockpit`); plus the dashboard's 🛡️ Agentic AI
    Control Plane link → MCP Servers → your `salestax-<INI>` in the catalog.
20. **Troubleshooting** — stage-1 wobble → `make stage1-scaffold` / `make stage-reset`;
    registered-but-not-callable → `make salestax-grant` + `bob-install-builder`;
    UUID-changes-on-reseed → re-run the matching install; "Bob narrates" → tell it
    to USE the tool, check Logs; 422 `SSRF_DNS_FAIL_CLOSED` → `make salestax-up`;
    phone can't reach a Codespaces public port → expected, presenter uses
    `make present` (cloudflared). `make demo-reset` / `make agents-reset`.
```

- [ ] **Step 3: Commit**

```bash
git add slides/outline.md
git commit -m "docs(slides): outline — Part A participation beat + tier-based Part B"
```

---

### Task 2: Bump `TOTAL` to 21

**Files:** Modify `slides/build_deck.py` (the `TOTAL = 20` line inside `build()`)

- [ ] **Step 1: Edit** `    TOTAL = 20` → `    TOTAL = 21`

- [ ] **Step 2: Commit**

```bash
git add slides/build_deck.py
git commit -m "chore(slides): TOTAL=21 for the added participation slide"
```

---

### Task 3: Part B slide 15 — chooser "3 ways to take part"

**Files:** Modify `slides/build_deck.py` — replace the old `# ---- 14.` block (the slide ending `footer(s, 14, TOTAL, dark=True)`), from its `# ----` comment through its `footer(...)` line.

- [ ] **Step 1: Replace the block with**

```python
    # ---- 15. PART B · CHOOSER: 3 WAYS TO TAKE PART ----------------------- #
    s = add_slide(prs)
    bg(s, DARK_BG)
    accent_bar(s, 0, 0, 13.333, 0.16, IBM_BLUE)
    textbox(s, 0.7, 0.5, 12.0, 0.4, [[("FOLLOW ALONG — APPENDIX", 13, SKY, True)]])
    title_on_light(s, "3 ways to take part", y=0.92, size=32, x=0.7, color=WHITE)
    tiers = [
        ("👀  Phone", "no install", MINT,
         "Scan the QR. Watch the four stages and run the scenarios in your browser.",
         "everyone"),
        ("🧪  Laptop Bob", "Bob, no Docker", SKY,
         "Install Bob, connect to the cloud control plane, drive the controls yourself.",
         "intermediate"),
        ("💻  Full local", "Docker + Bob", GOLD,
         "Run the whole governed mesh on your own machine — build it and govern it.",
         "advanced"),
    ]
    cw = (12.0 - 2 * 0.4) / 3
    cx = 0.7
    for head, tag, col, body, who in tiers:
        rounded(s, cx, 2.1, cw, 3.0, RGBColor(0x16, 0x20, 0x3C), line=None)
        accent_bar(s, cx, 2.1, cw, 0.12, col)
        textbox(s, cx + 0.26, 2.36, cw - 0.52, 0.5, [[(head, 19, WHITE, True, FONT_HEAD)]])
        textbox(s, cx + 0.26, 2.92, cw - 0.52, 0.34, [[(tag, 11.5, col, True, FONT_MONO)]])
        textbox(s, cx + 0.26, 3.36, cw - 0.52, 1.4, [[(body, 13, RGBColor(0xCF, 0xD8, 0xEE), False)]], line_spacing=1.16)
        textbox(s, cx + 0.26, 4.7, cw - 0.52, 0.34, [[(who, 11, col, True, FONT_BODY)]])
        cx += cw + 0.4
    textbox(s, 0.7, 5.55, 12.0, 0.9, [
        [("Everyone can watch ", 14, WHITE, False), ("and", 14, MINT, True),
         (" run the scenarios — no install. On a laptop, go deeper and drive the AI yourself.", 14, WHITE, False)],
    ], line_spacing=1.15)
    notes(s, """
PART B - the follow-along appendix. Three tiers, your comfort level. Most people
do Tier 1 (phone) - they already registered an agent live in Part A. Keen folks do
Tier 2 (laptop Bob); builders do Tier 3 (full local).

PRESENTER SETUP (do this before the talk): run `make present` in the Codespace (or
locally). It opens public cloudflared tunnels for the Companion (:7070) + gateway
(:4444), runs the Companion pointed at them, and opens your browser to the join QR.
Project that QR. WHY cloudflared and not the Codespaces forwarded ports: GitHub's
"public" forwarded ports return 404 to ANONYMOUS clients (a phone with no GitHub
login) - your logged-in laptop browser hides this. cloudflared gives a genuinely
public URL any phone reaches. The trycloudflare URL is RANDOM each run, so the QR is
generated live - never hardcode it. Reset the room count with `make agents-reset`.
""")
    footer(s, 15, TOTAL, dark=True)
```

- [ ] **Step 2: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part B chooser slide (3 ways to take part)"
```

---

### Task 4: Part B slide 16 — T1 📱 Phone

**Files:** Modify `slides/build_deck.py` — replace the old `# ---- 15.` block (`footer(s, 15, TOTAL)`).

- [ ] **Step 1: Replace with**

```python
    # ---- 16. PART B · TIER 1 · PHONE ------------------------------------ #
    s = add_slide(prs)
    bg(s, WHITE)
    accent_bar(s, 0, 0, 13.333, 0.16, GREEN)
    kicker(s, "Tier 1 · phone or laptop · no install", color=GREEN)
    title_on_light(s, "📱  Scan, register, run it")
    textbox(s, 0.7, 1.66, 12.0, 0.45,
            [[("Scan the QR on screen → the follow-along page → tap ", 14, INK, False),
              ("Run it live", 14, INK, True), (". Nothing to install.", 14, INK, False)]])
    rows = [
        ("1  Register your agent", "Type your initials → Register my agent ▶ → the /wall count climbs."),
        ("2  Run the scenarios", "One tap each: PII → REDACTED · injection → NEUTRALIZED · $50k → BLOCKED."),
        ("3  Watch the wall", "Every action checked, masked, logged, gated — at one seam, live."),
    ]
    y = 2.35
    for head, body in rows:
        rounded(s, 0.7, y, 12.0, 1.18, PANEL, line=PANEL_LINE)
        accent_bar(s, 0.7, y, 0.12, 1.18, GREEN)
        textbox(s, 1.05, y + 0.18, 11.4, 0.4, [[(head, 16, INK, True, FONT_BODY)]])
        textbox(s, 1.05, y + 0.62, 11.4, 0.45, [[(body, 13, MUTE, False)]])
        y += 1.34
    notes(s, """
TIER 1 - the inclusive entry. They already registered an agent live in Part A; here
they run the three governed scenarios from the dashboard with one tap each. The
point: zero install, real governance. The dashboard URL is the cloudflared tunnel
from `make present`; the QR is on screen.
""")
    footer(s, 16, TOTAL)
```

- [ ] **Step 2: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part B Tier 1 (phone) slide"
```

---

### Task 5: Part B slide 17 — T2 🧪 Laptop Bob

**Files:** Modify `slides/build_deck.py` — replace the old `# ---- 16.` block (`footer(s, 16, TOTAL)`).

- [ ] **Step 1: Replace with**

```python
    # ---- 17. PART B · TIER 2 · LAPTOP BOB ------------------------------- #
    s = add_slide(prs)
    bg(s, WHITE)
    accent_bar(s, 0, 0, 13.333, 0.16, IBM_BLUE)
    kicker(s, "Tier 2 · laptop + IBM Bob · no Docker")
    title_on_light(s, "🧪  Drive Bob against the cloud control plane")
    textbox(s, 0.7, 1.66, 12.0, 0.45,
            [[("Install Bob, then on the dashboard click ", 14, INK, False),
              ("🔌 Connect Bob", 14, INK, True),
              (" — copy / download / one-liner. ", 14, INK, False),
              ("No token typing.", 14, IBM_BLUE, True)]])
    code_panel(s, 0.7, 2.3, 6.0, 2.0, [
        ("# install (once)", MUTE),
        ("curl -fsSL https://bob.ibm.com/download/bobshell.sh | bash", CODE_FG),
        ("", None),
        ("# from an EMPTY folder — one fixed line:", MUTE),
        ("mkdir -p .bob && curl -fsSL \\", CODE_FG),
        ("  <dashboard>/bob/settings.json \\", CODE_FG),
        ("  -o .bob/settings.json && bob", CODE_FG),
    ], size=12.5, title="$ connect", title_color=SKY)
    rounded(s, 6.95, 2.3, 5.7, 2.0, PANEL, line=PANEL_LINE)
    textbox(s, 7.2, 2.5, 5.2, 1.8, [
        [("Then drive it (analyst):", 13, INK, True)],
        [("“Use the finbyte-gateway tools to fetch receipt rcpt_pii, verbatim.”", 12, IBM_BLUE, False, FONT_MONO)],
        [("“Use the finbyte-gateway tools to fetch receipt rcpt_injection, verbatim.”", 12, IBM_BLUE, False, FONT_MONO)],
        [("“Ask the auditor agent to pay $50,000 to Acme LLC.”", 12, IBM_BLUE, False, FONT_MONO)],
    ], line_spacing=1.18, space_after=6)
    rounded(s, 0.7, 4.55, 12.0, 1.0, DARK_BG, line=None)
    textbox(s, 1.0, 4.7, 11.4, 0.8, [
        [("Same cloud control plane as the phones.  ", 14, MINT, True),
         ("Gotchas: ", 13, WHITE, False), ("-t http", 13, SKY, True, FONT_MONO),
         (" (never SSE), empty folder, copy the FULL token (the page guarantees it).", 13, WHITE, False)],
    ], anchor=MSO_ANCHOR.MIDDLE, line_spacing=1.12)
    notes(s, """
TIER 2 - laptop Bob. They install only Bob (no Docker) and point it at the cloud
control plane. The Connect Bob page hands out the command / settings.json / one-liner
so nobody types the ~470-char token. Drive the three CANONICAL prompts (explicit
"use the finbyte-gateway tools" wording forces the tool call). Connects to the same
gateway tunnel from `make present`.
""")
    footer(s, 17, TOTAL)
```

- [ ] **Step 2: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part B Tier 2 (laptop Bob) slide"
```

---

### Task 6: Part B slide 18 — T3 💻 Full local · build & govern

**Files:** Modify `slides/build_deck.py` — replace the old `# ---- 17.` block (`footer(s, 17, TOTAL)`).

- [ ] **Step 1: Replace with**

```python
    # ---- 18. PART B · TIER 3 · FULL LOCAL — BUILD & GOVERN -------------- #
    s = add_slide(prs)
    bg(s, WHITE)
    accent_bar(s, 0, 0, 13.333, 0.16, GOLD)
    kicker(s, "Tier 3 · full local · Docker + Bob", color=GOLD)
    title_on_light(s, "💻  Build it and govern it, end to end")
    textbox(s, 0.7, 1.66, 12.0, 0.45,
            [[("One command for the finished mesh — or walk the build by hand.", 14, INK, False)]])
    code_panel(s, 0.7, 2.3, 5.85, 1.5, [
        ("git clone …/ai-agent-controlplane-demo", CODE_FG),
        ("make quickstart", MINT),
        ("  → finished governed mesh · 16/16 proven", MUTE),
    ], size=13, title="$ one command", title_color=MINT)
    code_panel(s, 6.8, 2.3, 5.85, 1.5, [
        ("make stage1-build   # server.py → 108.50, UNGOVERNED :8000", CODE_FG),
        ("make stage2-govern  # register (not callable yet)", CODE_FG),
        ("make salestax-grant # grant → CALL → 108.50 governed", MINT),
    ], size=12, title="$ or walk it", title_color=SKY)
    rounded(s, 0.7, 4.1, 12.0, 1.5, PANEL, line=PANEL_LINE)
    textbox(s, 1.0, 4.3, 11.4, 1.2, [
        [("The throughline:  ", 15, GOLD, True),
         ("register → grant → call", 15, INK, True, FONT_MONO)],
        [("Registering only catalogs the tool; ", 13, INK, False),
         ("granting", 13, INK, True), (" is the separate, privileged step that makes it callable. ", 13, INK, False),
         ("add_tax(100, 8.5) → tax=8.50, total=108.50", 12.5, GREEN, True, FONT_MONO)],
    ], anchor=MSO_ANCHOR.MIDDLE, line_spacing=1.2, space_after=6)
    notes(s, """
TIER 3 - full local, for the builders. `make quickstart` is the one-command finished
mesh (16/16, no Bob needed). Or walk it: stage1-build (server.py runs bare on :8000,
ungoverned) → stage2-govern (register, NOT callable) → salestax-grant + the builder
persona (call → 108.50 governed). Same register→grant→call throughline as Part A's
Stage ②. Fallback `make stage1-scaffold`; reset `make stage-reset`.
""")
    footer(s, 18, TOTAL)
```

- [ ] **Step 2: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part B Tier 3 build-and-govern slide"
```

---

### Task 7: Part B slide 19 — T3 💻 Full local · controls + proof

**Files:** Modify `slides/build_deck.py` — replace the old `# ---- 18.` block (`footer(s, 18, TOTAL)`).

- [ ] **Step 1: Replace with**

```python
    # ---- 19. PART B · TIER 3 · CONTROLS + PROOF ------------------------- #
    s = add_slide(prs)
    bg(s, WHITE)
    accent_bar(s, 0, 0, 13.333, 0.16, GOLD)
    kicker(s, "Tier 3 · the four controls + the proof", color=GOLD)
    title_on_light(s, "💻  Watch each guardrail bite — then prove it")
    code_panel(s, 0.7, 1.8, 12.0, 1.05, [
        ("make stage3-controls    # seed the FinOps mesh, Bob → analyst", CODE_FG),
        ("make logs-opa           # second pane: live ALLOW / DENY", MUTE),
    ], size=13, title="$ controls", title_color=SKY)
    fires = [
        ("“…fetch receipt rcpt_pii, verbatim.”", "REDACTED → ***-**-6789, [SECRET_REDACTED]", IBM_BLUE),
        ("“…fetch receipt rcpt_injection, verbatim.”", "NEUTRALIZED → [INJECTION_BLOCKED]", RED),
        ("“Ask the auditor agent to pay $50,000 to Acme LLC.”", "BLOCKED by policy (cross-language Py→Rust)", RED),
    ]
    y = 3.05
    for say, got, col in fires:
        rounded(s, 0.7, y, 12.0, 0.84, PANEL, line=PANEL_LINE)
        textbox(s, 1.0, y + 0.14, 6.4, 0.6, [[(say, 12.5, INK, False, FONT_MONO)]], anchor=MSO_ANCHOR.MIDDLE)
        textbox(s, 7.5, y + 0.14, 5.0, 0.6, [[("→ ", 12.5, MUTE, False), (got, 12.5, col, True)]], anchor=MSO_ANCHOR.MIDDLE)
        y += 0.98
    rounded(s, 0.7, 6.05, 12.0, 0.78, DARK_BG, line=None)
    textbox(s, 1.0, 6.16, 11.4, 0.6, [
        [("make verify-controls", 15, MINT, True, FONT_MONO),
         ("  →  16 passed, 0 failed", 15, WHITE, True)],
    ], anchor=MSO_ANCHOR.MIDDLE)
    notes(s, """
TIER 3 controls. `make stage3-controls` seeds the FinOps mesh and switches Bob to the
analyst persona (8 tools, no wire). Drive the three canonical prompts; each fires a
control. Then `make verify-controls` proves all of it deterministically: 16 passed,
0 failed - identical to quickstart's end-state, but you watched it.
""")
    footer(s, 19, TOTAL)
```

- [ ] **Step 2: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part B Tier 3 controls + proof slide"
```

---

### Task 8: Part B slides 20 & 21 — Watch the control plane + Troubleshooting

**Files:** Modify `slides/build_deck.py` — replace the old `# ---- 19.` block (`footer(s, 19, TOTAL)`) and the old `# ---- 20.` block (`footer(s, 20, TOTAL)`).

- [ ] **Step 1: Replace the old `# ---- 19.` block with**

```python
    # ---- 20. PART B · WATCH THE CONTROL PLANE --------------------------- #
    s = add_slide(prs)
    bg(s, WHITE)
    accent_bar(s, 0, 0, 13.333, 0.16, IBM_BLUE)
    kicker(s, "See the governance for yourself")
    title_on_light(s, "Watch the control plane — the tools")
    tools = [
        ("🛡️  Admin UI", "make monitor", "The catalog + live Logs. The dashboard's 🛡️ Agentic AI Control Plane link opens it — MCP Servers shows YOUR salestax-<INI>."),
        ("🔍  MCP Inspector", "make inspect-mcp", "The 8 governed FinOps tools — wire ABSENT; get_receipt returns REDACTED live."),
        ("🤝  A2A Inspector", "make inspect-a2a", "The Python auditor + Rust payments agent cards — the cross-language pair the $50k block fires across."),
    ]
    y = 1.95
    for head, cmd, body in tools:
        rounded(s, 0.7, y, 12.0, 1.45, PANEL, line=PANEL_LINE)
        accent_bar(s, 0.7, y, 0.12, 1.45, IBM_BLUE)
        textbox(s, 1.05, y + 0.18, 5.0, 0.4, [[(head, 15, INK, True, FONT_BODY)]])
        textbox(s, 1.05, y + 0.62, 5.0, 0.34, [[(cmd, 12, IBM_BLUE, True, FONT_MONO)]])
        textbox(s, 6.1, y + 0.2, 6.4, 1.1, [[(body, 12.5, MUTE, False)]], line_spacing=1.14, anchor=MSO_ANCHOR.MIDDLE)
        y += 1.6
    textbox(s, 0.7, 6.85, 12.0, 0.4,
            [[("One command for all of it: ", 13, INK, False), ("make cockpit", 13, IBM_BLUE, True, FONT_MONO),
              (" — tmux tiles Bob + watch panes + the Companion.", 13, INK, False)]])
    notes(s, """
WATCH THE CONTROL PLANE. Three real ecosystem tools. The Admin UI (make monitor, or
the dashboard's new 🛡️ Agentic AI Control Plane link) - MCP Servers lists every
registered server INCLUDING the room's salestax-<INI> agents. MCP Inspector - the 8
governed FinOps tools, wire absent, redaction live. A2A Inspector - the Python + Rust
agent cards. `make cockpit` tiles everything.
""")
    footer(s, 20, TOTAL)
```

- [ ] **Step 2: Replace the old `# ---- 20.` block with**

```python
    # ---- 21. PART B · TROUBLESHOOTING ----------------------------------- #
    s = add_slide(prs)
    bg(s, DARK_BG)
    accent_bar(s, 0, 0, 13.333, 0.16, GOLD)
    textbox(s, 0.7, 0.5, 12.0, 0.4, [[("FOLLOW ALONG — APPENDIX", 13, SKY, True)]])
    title_on_light(s, "Troubleshooting", y=0.92, size=32, x=0.7, color=WHITE)
    items = [
        ("Stage-1 build wobbles", "make stage1-scaffold  ·  make stage-reset"),
        ("Registered but not callable", "make salestax-grant + make bob-install-builder (grant is separate)"),
        ("UUID changed after reseed", "re-run the matching make bob / bob-operator / bob-install-builder"),
        ("Bob narrates instead of acting", "tell it to USE the finbyte-gateway tools; check monitor Logs"),
        ("Registration 422 (DNS / SSRF)", "the sales-tax backend isn't up → make salestax-up"),
        ("Phone can't open the Codespaces URL", "expected — GitHub public ports 404 anon; use make present (cloudflared)"),
    ]
    y = 1.9
    for head, fix in items:
        textbox(s, 0.7, y, 5.4, 0.6, [[(head, 13.5, WHITE, True)]], anchor=MSO_ANCHOR.MIDDLE)
        textbox(s, 6.2, y, 6.45, 0.6, [[(fix, 12.5, MINT, False, FONT_MONO)]], anchor=MSO_ANCHOR.MIDDLE, line_spacing=1.05)
        y += 0.78
    textbox(s, 0.7, 6.7, 12.0, 0.4,
            [[("Nuke it from orbit: ", 13, RGBColor(0x9F, 0xB3, 0xD9), False),
              ("make demo-reset", 13, GOLD, True, FONT_MONO),
              ("  ·  reset the room count: ", 13, RGBColor(0x9F, 0xB3, 0xD9), False),
              ("make agents-reset", 13, GOLD, True, FONT_MONO)]])
    notes(s, """
TROUBLESHOOTING. The usual stage gotchas, plus the two we hit building the room
demo: 422 SSRF_DNS_FAIL_CLOSED means the sales-tax backend isn't up (make
salestax-up; make present/companion now auto-ensure it). And a phone can't reach a
Codespaces "public" forwarded port - that's GitHub returning 404 to anonymous
clients, not a bug - which is exactly why `make present` tunnels through cloudflared.
make demo-reset for a clean slate; make agents-reset to zero the wall count.
""")
    footer(s, 21, TOTAL)
```

- [ ] **Step 3: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part B watch + troubleshooting slides"
```

---

### Task 9: Renumber the post-Govern Part A footers (7→8 … 13→14)

Part B now occupies 15–21, so 14 is free. Renumber **highest source first** so each target index is unoccupied at edit time. Each source line is unique.

**Files:** Modify `slides/build_deck.py`

- [ ] **Step 1: Apply these edits in this exact order**

```
footer(s, 13, TOTAL, dark=True)  →  footer(s, 14, TOTAL, dark=True)
footer(s, 12, TOTAL)             →  footer(s, 13, TOTAL)
footer(s, 11, TOTAL)             →  footer(s, 12, TOTAL)
footer(s, 10, TOTAL)             →  footer(s, 11, TOTAL)
footer(s, 9, TOTAL)              →  footer(s, 10, TOTAL)
footer(s, 8, TOTAL)              →  footer(s, 9, TOTAL)
footer(s, 7, TOTAL)              →  footer(s, 8, TOTAL)
```
(Only the takeaways/close slide uses `dark=True`; all others are the plain form.)

- [ ] **Step 2: Verify** — footers are now 1–6 and 8–21, with 7 missing (the gap for the new slide):

```bash
grep -oE "footer\(s, [0-9]+," slides/build_deck.py | grep -oE "[0-9]+" | sort -n | uniq -c
```
Expected: `1` for each of 1,2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19,20,21 (no 7).

- [ ] **Step 3: Commit**

```bash
git add slides/build_deck.py
git commit -m "chore(slides): renumber Part A footers 7-13 -> 8-14"
```

---

### Task 10: Insert the Part A participation slide (footer 7) after ② Govern

**Files:** Modify `slides/build_deck.py` — insert immediately AFTER the line `    footer(s, 6, TOTAL)` (end of the ② Govern block) and BEFORE the next `# ---- 7. THREE PERSONAS` comment.

- [ ] **Step 1: Insert this new block**

```python

    # ---- 7. PART A · NOW THE ROOM BUILDS AGENTS (live participation) ----- #
    s = add_slide(prs)
    bg(s, DARK_BG)
    accent_bar(s, 0, 0, 13.333, 0.16, MINT)
    textbox(s, 0.7, 0.5, 12.0, 0.4, [[("YOUR TURN — LIVE", 13, MINT, True)]])
    title_on_light(s, "Now the room builds agents", y=0.92, size=32, x=0.7, color=WHITE)
    textbox(s, 0.7, 1.78, 12.0, 0.5, [
        [("Bob just registered the sales-tax server. ", 15, WHITE, False),
         ("Now you:", 15, MINT, True),
         (" scan → name an agent with your initials → it's in the catalog.", 15, WHITE, False)],
    ], line_spacing=1.1)
    # QR placeholder (the real QR is projected live from the companion's /qr)
    rounded(s, 0.7, 2.6, 3.4, 3.4, WHITE, line=None)
    textbox(s, 0.7, 3.9, 3.4, 0.8, [[("QR", 40, RGBColor(0xC8, 0xD0, 0xE0), True, FONT_HEAD)]], align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    textbox(s, 0.7, 6.05, 3.4, 0.4, [[("↑ scan the QR on screen", 12, MINT, True)]], align=PP_ALIGN.CENTER)
    # the wall count
    rounded(s, 4.45, 2.6, 8.2, 3.4, RGBColor(0x16, 0x20, 0x3C), line=None)
    textbox(s, 4.45, 2.9, 8.2, 0.5, [[("AGENTS BUILT BY THE ROOM", 15, SKY, True)]], align=PP_ALIGN.CENTER)
    textbox(s, 4.45, 3.3, 8.2, 1.6, [[("47", 96, MINT, True, FONT_HEAD)]], align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    textbox(s, 4.45, 5.05, 8.2, 0.5, [[("0 → live on the projected wall", 14, RGBColor(0xCF, 0xD8, 0xEE), False, FONT_BODY, True)]], align=PP_ALIGN.CENTER)
    textbox(s, 4.7, 5.5, 7.7, 0.4, [[("MG", 13, MINT, True, FONT_MONO), ("   TT   AB   PK   JS   KL   …", 13, RGBColor(0x9F, 0xB3, 0xD9), False, FONT_MONO)]], align=PP_ALIGN.CENTER)
    textbox(s, 0.7, 6.65, 12.0, 0.5, [
        [("Every one is a ", 14, WHITE, False), ("real", 14, MINT, True),
         (" MCP server registered with the control plane — the count is real catalog entries.", 14, WHITE, False)],
    ], align=PP_ALIGN.CENTER)
    notes(s, """
NOW THE ROOM BUILDS AGENTS (live participation - the engagement beat). It lands right
after Stage ② Govern, where Bob just registered a server: now the audience does the
same. They scan the on-screen QR (the companion's /qr from `make present`), type their
initials, tap Register - and the projected /wall count climbs 0 → N with their
initials. Each registration is a REAL POST /gateways: a genuine, enabled, reachable
salestax-<INI> entry in the ContextForge catalog (show it in the Admin UI later).
Reset to 0 before the talk with `make agents-reset`. The "47" on the slide is just a
mock - the real number is on the wall. KEY LINE: "You didn't tap a counter - you each
registered a real MCP server with the control plane, live."
""")
    footer(s, 7, TOTAL)
```

- [ ] **Step 2: Verify footer indices are now 1..21, each once**

```bash
grep -oE "footer\(s, [0-9]+," slides/build_deck.py | grep -oE "[0-9]+" | sort -n | uniq -c
```
Expected: `1` for each of 1 through 21.

- [ ] **Step 3: Commit**

```bash
git add slides/build_deck.py
git commit -m "feat(slides): Part A live participation slide (room builds agents)"
```

---

### Task 11: Regenerate the deck + verify

- [ ] **Step 1: Remove the stale PowerPoint lock file if present**

```bash
rm -f "slides/~\$bob-controlplane-talk.pptx"
```

- [ ] **Step 2: Regenerate**

```bash
uv run --with python-pptx==1.0.2 python slides/build_deck.py
```
Expected: no traceback; writes `slides/bob-controlplane-talk.pptx`.

- [ ] **Step 3: Verify slide count = 21**

```bash
uv run --with python-pptx==1.0.2 python -c "from pptx import Presentation; print(len(Presentation('slides/bob-controlplane-talk.pptx').slides))"
```
Expected: `21`

- [ ] **Step 4: Spot-check content is present**

```bash
uv run --with python-pptx==1.0.2 python -c "
from pptx import Presentation
p=Presentation('slides/bob-controlplane-talk.pptx')
txt='\n'.join(sh.text_frame.text for s in p.slides for sh in s.shapes if sh.has_text_frame)
for needle in ['Now the room builds agents','3 ways to take part','Drive Bob against','fetch receipt rcpt_pii, verbatim','Agentic AI Control Plane','Troubleshooting','salestax']:
    print(('OK  ' if needle in txt else 'MISSING  ')+needle)
"
```
Expected: every line starts with `OK`.

- [ ] **Step 5: Commit the regenerated deck**

```bash
git add slides/bob-controlplane-talk.pptx
git commit -m "build(slides): regenerate deck with 3-tier follow-along + participation"
```

---

## Self-review notes
- **Spec coverage:** Part A participation slide (Task 10) ✓; Part B chooser (3) ✓; T1 (4) ✓; T2 (5) ✓; T3 build/govern (6) ✓; T3 controls (7) ✓; watch + Control-Plane link (8) ✓; troubleshooting incl. 422 + Codespaces-port note (8) ✓; canonical prompts (Tasks 5/7) ✓; presenter setup in notes (3) ✓; outline.md (1) ✓; regenerate + verify (11) ✓.
- **Numbering:** Part B → 15–21 first (Tasks 3–8), then renumber Part A 7–13 → 8–14 (Task 9), then insert footer 7 (Task 10). No duplicate `footer(s, N, …)` at any edit step.
- **Out of scope:** A2A participant agents (issue #22); theme/restyle.
