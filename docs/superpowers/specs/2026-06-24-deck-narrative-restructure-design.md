# Talk deck — Part A narrative restructure (Act 0)

**Date:** 2026-06-24
**Status:** approved, ready for implementation plan
**Branch:** deck-followalong-refresh (continues the deck work; one PR for the whole deck overhaul)

## Goal

Give the talk a stronger conceptual on-ramp. Restructure the front of Part A into an
"Act 0" that grounds the audience before the hands-on build: what an agent is, the two
protocols and the problems they solve, the thesis (governing is the hard part), the
architecture they're about to build, and how to follow along. This **replaces** the
current slides 2–3 ("The problem", "MCP vs A2A") rather than piling on, and pulls the
follow-along chooser to the front. Then regenerate `slides/bob-controlplane-talk.pptx`.

Builds on the just-merged-on-branch follow-along refresh (participation slide + Part B
tier slides). Source of truth: `slides/outline.md`; renderer: `slides/build_deck.py`.

## New Part A order (18 slides)

1. **Title** — unchanged.
2. **AI Agent 101 — "What is an agent?"** *(NEW, with an SVG)*.
3. **MCP — the problem it solves** *(NEW)*.
4. **A2A — the problem that led to it + the result** *(NEW)*.
5. **Thesis — "Building agents is easy. Governing them is the hard part."** *(reframes the old "The problem" slide; the old content is replaced)*.
6. **The architecture — the harness we'll build** *(NEW; reuses the existing `slides/assets/architecture.png`)*.
7. **Three ways to follow along** — the chooser, MOVED up from Part B.
8. The progressive build (spine) — existing.
9. ① Build — existing.
10. ② Govern — existing.
11. Now the room builds agents (participation) — existing.
12. Three personas — existing.
13–16. ③ Controls ×4 (Policy, Data, Injection, RBAC) — existing.
17. **④ Mesh** — existing, but reframed as a CALLBACK to slide 6: "you just built this diagram."
18. Takeaways + CTA — existing.

## Part B (6 slides)

Chooser removed (now slide 7). Part B opens directly with the tiers:
T1 phone · T2 laptop Bob · T3 build/govern · T3 controls+proof · watch · troubleshooting.

## Deck size

21 → ~24 slides (net +3: Agent 101, A2A, architecture-overview are new; thesis replaces
"the problem"; MCP replaces "MCP vs A2A"; chooser moves front, net 0). Acceptable for a
~40-min talk.

## New slide content

### Slide 2 — AI Agent 101 + SVG
- **SVG asset:** `slides/assets/agent-101.svg` (the explicit deliverable). A central
  **"Agent" (LLM brain)** hub with trait nodes around it:
  - 🧠 **Reasoning / planning** — decides the next step, loops toward a goal
  - 💾 **Memory** — short-term context + longer-term recall
  - 🛠️ **Tools / actions** — executes tasks (calls tools, APIs, moves things)
  - 📚 **Knowledge** — grounding / retrieval / context
  - 🎯 **Goals / autonomy** — pursues an objective without step-by-step instructions
- Clean radial/hub layout, IBM-blue (`#0F62FE`) palette + dark/ink text to match the
  deck. One-line takeaway on the slide: *"An agent isn't a chatbot — it remembers,
  plans, and acts."*
- **Render path:** python-pptx cannot embed SVG. Render `agent-101.svg` → `agent-101.png`
  (headless browser screenshot or an SVG→PNG converter) and embed the PNG, mirroring the
  architecture-diagram pattern, with a committed-PNG fallback so a matplotlib-free build
  still shows it. Preview the SVG to the user before wiring it in.

### Slide 3 — MCP, the problem it solves
- Problem: every model↔tool integration is bespoke (N×M glue). MCP standardizes the
  **model → tools** seam (vertical). "Bob speaks MCP to reach any tool — one protocol,
  any backend."

### Slide 4 — A2A, the problem + result
- Problem: agents need to call *other* agents, across vendors and languages. A2A
  standardizes the **agent → agent** seam (horizontal). Result in this demo: the Python
  **auditor** ↔ Rust **payments** pair (the cross-language hop the $50k block fires across).

### Slide 5 — Thesis
- *Building* an agent that moves money takes ~30 seconds (Bob does it live in Stage ①).
  **Governing** it — auth, policy, redaction, audit, RBAC — is the hard, unsolved part.
  "MCP and A2A say how agents connect; neither says who's allowed to do what, or proves
  it." Sets up the whole talk.

### Slide 6 — Architecture overview (the harness)
- Reuse the existing `architecture.png`, framed forward: "here's the control plane we'll
  assemble by hand — one checkpoint every tool call and every agent-to-agent call passes
  through." Pairs with slide 17 (④ Mesh) as a bookend.

## Mechanics

- Create `slides/assets/agent-101.svg`; render to `slides/assets/agent-101.png`; commit both.
- `slides/build_deck.py`:
  - Add an SVG/PNG load for the agent diagram alongside the existing `have_png`/`ARCH_PNG`
    pattern (render-or-committed-fallback), so the build degrades gracefully.
  - Insert the 5 new slide blocks (Agent 101, MCP, A2A, thesis, architecture-overview)
    after the Title slide; move the chooser block from Part B to slide 7; reframe the
    ④ Mesh slide copy as a callback; renumber all footers; bump `TOTAL` to the new count.
  - Reuse existing helpers (`add_slide`, `bg`, `kicker`, `title_on_light`, `textbox`,
    `code_panel`, `rounded`, `accent_bar`, `notes`, `footer`) and theme colors. No new
    styling system.
- `slides/outline.md`: rewrite the Part A list to the new order; note Part B drops its
  chooser.
- Regenerate `slides/bob-controlplane-talk.pptx` (with matplotlib + pillow) and verify it
  builds, the slide count matches, footers are sequential, and the architecture +
  agent-101 images embed.

## Testing / acceptance

- `build_deck.py` runs clean (with `--with python-pptx --with matplotlib --with pillow`).
- Slide count == the new total (~24); footers 1..N each exactly once.
- Both images embed: the agent-101 diagram on slide 2 and the architecture diagram on
  slides 6 and 17 (3 embedded pictures total, or 2 if 6 and 17 share — confirm 6 and 17
  both carry the architecture picture).
- Text spot-check: "What is an agent", "MCP", "A2A", the thesis line, "Three ways to take
  part" on slide 7 (not in Part B), "you just built" callback wording on the Mesh slide.
- `make check-prompts` still green (Part B canonical prompts unchanged).
- Visual review by the user (Keynote/PowerPoint) — layout/overflow, the SVG looks good.

## Out of scope

- A2A participant agents (issue #22).
- Restyling or re-content of the existing build/stage/control slides beyond the ④ Mesh
  callback reframing.
- A new architecture diagram — slide 6 reuses the existing `architecture.png`.
