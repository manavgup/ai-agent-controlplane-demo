# Talk deck — follow-along refresh (3-tier + live participation)

**Date:** 2026-06-24
**Status:** approved, ready for implementation plan
**Branch:** deck-followalong-refresh

## Goal

Update the Bob Developer Day talk deck so it matches the follow-along experience we
actually built (3 tiers + phone QR + audience registration), instead of the old
"everyone clones the repo and runs the full Docker stack" model that the deck still
describes. Two changes: a live **participation beat** in Part A, and a **tier-based
rewrite** of the Part B follow-along appendix.

Source of truth is `slides/outline.md`; `slides/build_deck.py` renders it into
`slides/bob-controlplane-talk.pptx`. Both get edited, then the `.pptx` is regenerated.

## Background / why

The deck (built 2026-06-14) predates the non-coder follow-along work merged in PR #21.
Part A (the conceptual talk, slides 1–13) is still accurate. Part B (the follow-along
appendix, slides 14–20) describes the superseded model and must be reworked. The new
experience: a 3-tier chooser (👀 phone / 🧪 laptop Bob / 💻 full local), phones join
via a QR served by the companion (`make present` → cloudflared public tunnel), and
attendees **register their own agent** (`salestax-<INITIALS>`) which appears live on a
projected `/wall` count.

## Change 1 — Part A: one new "participation" slide

Insert **one new slide immediately after the ② Govern slide** (the
`register → grant → call` slide, currently slide 6).

- **Title:** "Now the room builds agents" (or similar).
- **Beat:** *Bob just registered the sales-tax server. Now you: scan → name an agent
  with your initials → it's in the catalog.* The room registers their own agents and
  the presenter shows the **/wall count climbing 0 → N** with initials chips.
- **Throughline carried:** "the room just registered N **real** MCP servers with the
  control plane, live" — makes the abstract `register` step a shared moment, right
  where the concept lands.
- **QR handling:** the slide shows a **QR placeholder graphic + "scan the QR on
  screen"** — NOT a baked-in QR image, because cloudflared quick-tunnel URLs are
  random per session. The live QR is the companion's `/qr` page, projected separately.
- **Visual:** mock `/wall` (giant count + a few initials chips) + the QR placeholder.
- **Speaker notes:** presenter has `make present` running (companion on the cloudflared
  tunnel); project `/qr`; let the room register; narrate the count. Reset with
  `make agents-reset` before the session.

Part A goes 13 → 14 slides.

## Change 2 — Part B: tier-based rewrite (~7 slides)

Replace slides 14–20 with:

1. **Chooser — "3 ways to take part"** — 👀 phone / 🧪 laptop Bob / 💻 full local,
   one line each (mirrors `docs/follow.html`). Speaker notes hold the presenter setup
   (`make present`, why GitHub Codespaces public ports 404 anonymous clients).
2. **T1 📱 Phone** — scan the QR → follow-along page → run the 3 governed scenarios
   (PII redacted / injection neutralized / $50k blocked). No install. (Recap; the
   register beat already happened in Part A.)
3. **T2 🧪 Laptop Bob** *(NEW)* — install Bob → open the dashboard's **🔌 Connect Bob**
   → copy the command / download `settings.json` / one-liner (no token typing) → drive
   the 3 canonical prompts → governed. Note: connects to the same cloud control plane.
4. **T3 💻 Full local — build & govern** — `make quickstart` (finished mesh, 16/16), or
   walk ① build (`make stage1-build` → 108.50 ungoverned) → ② govern (register → grant
   → call → 108.50 governed). Condensed from the current ~2 build slides into one.
5. **T3 💻 Full local — controls + proof** — `make stage3-controls` + the 3 analyst
   prompts + `make verify-controls` → **16 passed, 0 failed**.
6. **Watch the control plane** — `make monitor` (Admin UI) / `make inspect-mcp` /
   `make inspect-a2a`, or `make cockpit`. Plus the new **🛡️ Agentic AI Control Plane**
   dashboard link → MCP Servers → see *your* registered `salestax-<INI>` in the catalog.
7. **Troubleshooting** — existing gotchas (stage-1 wobble → `make stage1-scaffold` /
   `make stage-reset`; registered-but-not-callable → `make salestax-grant` +
   `bob-install-builder`; UUID-changes-on-reseed → re-run the matching install; "Bob
   narrates" → tell it to USE the tool, check Logs) **plus NEW**: 422
   `SSRF_DNS_FAIL_CLOSED` → `make salestax-up`; phone can't reach a Codespaces public
   port → expected (presenter uses `make present` / cloudflared, not GitHub forwarding).

## Cross-cutting fixes

- **Canonical drive prompts everywhere** — use the exact wording from
  `docs/assets/prompts.json`:
  - `Use the finbyte-gateway tools to fetch receipt rcpt_pii, verbatim.`
  - `Use the finbyte-gateway tools to fetch receipt rcpt_injection, verbatim.`
  - `Ask the auditor agent to pay $50,000 to Acme LLC.`
  Replaces the deck's old shorthand (`Show me receipt rcpt_pii.`, `wire $50k yourself`).
- **Presenter setup stays out of attendee slides** — `make present` + the
  cloudflared / anonymous-port rationale live in **speaker notes** (chooser slide) and
  the runsheet (already updated), not on the attendee-facing slide bodies.

## Verbatim strings to keep (unchanged, still valid)

- Stage-1 proof: `add_tax(100, 8.5) → tax=8.50, total=108.50`
- Block reason: `Plugin Violation: Wire amount 50000 exceeds the $10,000 auto-approve
  limit and requires dual approval (approval=true). FinByte T&E policy §2.`
- Masked: `SSN ***-**-6789, card ****-****-****-1111 … api key [SECRET_REDACTED]`
- Injection neutralized: `[INJECTION_BLOCKED]`

## Mechanics

- Edit `slides/outline.md` (source of truth) to reflect the new Part A slide + Part B
  structure.
- Edit `slides/build_deck.py` — add the Part A participation slide block; replace the
  Part B slide blocks with the 7 tier slides. Reuse existing helpers (`add_slide`,
  `textbox`, `code_panel`, `stage_header`, `kicker`, `notes`, theme colors). No new
  theme/styling system.
- Regenerate `slides/bob-controlplane-talk.pptx` by running the build script; verify it
  builds without error and the slide count is ~21–22.
- Delete the stale PowerPoint lock file `slides/~$bob-controlplane-talk.pptx`
  (untracked junk) if present.

## Testing / acceptance

- `build_deck.py` runs clean and writes the `.pptx`.
- Slide count ≈ 21–22 (Part A 14 + Part B 7, plus any title/section slides).
- Spot-check rendered slides: the new Part A participation slide exists with the
  /wall + QR-placeholder; Part B opens with the chooser; T2 laptop-Bob slide present;
  canonical prompts appear; troubleshooting has the 2 new entries.
- `outline.md` and the rendered deck agree (outline is the source of truth).

## Out of scope

- A2A participant agents (tracked separately in issue #22).
- Theme / visual restyle, new slide-layout helpers, or Part A conceptual changes
  beyond the one inserted participation slide.
- Baking a static QR image into the deck (URLs are per-session; QR is projected live).
