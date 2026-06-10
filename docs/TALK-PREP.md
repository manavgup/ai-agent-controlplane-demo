# Talk Preparation Guide — 50-Minute Conference Talk

**Talk:** IBM Bob × ContextForge — Who's in charge of your agents?  
**Duration:** 50 minutes (30 min talk + 12 min live demo + 5 min Q&A + 3 min buffer)  
**Audience:** Mixed exec + technical  
**Format:** Live attendee participation (everyone runs the demo)

---

## Executive Summary

**Your strongest assets:**
1. ✅ **One-command setup** (`make quickstart`) that proves 16/16 controls headlessly
2. ✅ **Comprehensive documentation** (README, QUICKSTART, RUNBOOK all excellent)
3. ✅ **Real ecosystem tools** (ContextForge monitor, MCP Inspector, A2A Inspector)
4. ✅ **Cross-language proof** (Python → Rust agent governance)
5. ✅ **Deterministic proof suite** (works without Bob installed)

**Key risks to mitigate:**
1. ⚠️ Conference WiFi (image pulls) → **Pre-pull strategy**
2. ⚠️ Bob variability (narrates vs. calls tools) → **Fallback to verify-controls**
3. ⚠️ Time management (50 min is tight) → **Strict timing + skip slides**

---

## Talk Structure & Timing

### Recommended Flow (50 minutes total)

```
00:00-00:03  [3 min]  Title + Problem Setup
00:03-00:08  [5 min]  Architecture Overview (the cast)
00:08-00:20  [12 min] Act 1: Four Money Shots (live Bob)
00:20-00:28  [8 min]  Act 2: Bob Operates the Control Plane
00:28-00:35  [7 min]  Proof + Observability Tools
00:35-00:42  [7 min]  Attendee Quickstart (live setup)
00:42-00:47  [5 min]  Q&A
00:47-00:50  [3 min]  Buffer / Overflow
```

### Detailed Breakdown

#### Opening (3 min)
- **Slide 1:** Title + QR code (scan now)
- **Hook:** "We handed an AI agent the keys to a fintech payments system. Watch what happens when it tries to wire $50,000."
- **Promise:** "In 50 minutes, you'll see four controls fire live, and you'll run this on your laptop."

#### Architecture (5 min)
- **Slide 2-3:** The problem (MCP + A2A, who governs?)
- **Slide 4:** The cast (Bob + 6 MCP servers + 2 A2A agents + ContextForge)
- **Slide 5:** Architecture diagram
- **Key point:** "One governed seam — the gateway tool hooks"

#### Act 1: Four Money Shots (12 min — 3 min each)
- **Slide 6:** Money Shot #1 — Policy (OPA)
  - Live in Bob: *"Wire $50,000 to Acme LLC for expense exp_big"*
  - **BLOCKED** → show monitor Logs
  - Then: *"...with dual approval"* → **ALLOWED**
  - Cross-language: Auditor→Payments $50k also blocked
  - **Timing:** 3 min (prompt + wait + explain)

- **Slide 7:** Money Shot #2 — Data Protection
  - Live in Bob: *"Fetch receipt rcpt_pii, verbatim"*
  - **REDACTED** → SSN `***-**-6789`, card `****-****-****-1111`, key `[SECRET_REDACTED]`
  - **Timing:** 2 min (faster, just show output)

- **Slide 8:** Money Shot #3 — Prompt Injection
  - Live in Bob: *"Fetch receipt rcpt_injection"*
  - **NEUTRALIZED** → `[INJECTION_BLOCKED]`
  - **Timing:** 2 min

- **Slide 9:** Money Shot #4 — Least Privilege
  - Live in Bob: *"Wire $50k yourself, directly"*
  - Bob has **no wire tool** (show MCP Inspector)
  - **Timing:** 3 min (switch to Inspector)

**Fallback if Bob misbehaves:** Switch to `make verify-controls` (16/16 proof) and narrate from the script output.

#### Act 2: Bob Operates the Control Plane (8 min)
- **Slide 10:** Persona switch
  - Quit Bob, run `make bob-operator`
  - **Key point:** "Same agent, different RBAC scope"

- **Slide 11-14:** Four operator beats (2 min each)
  1. *"List everything ContextForge is governing"* → `list_control_plane`
  2. *"Would a $50k wire be allowed? With dual approval?"* → `evaluate_policy`
  3. *"Register fx-rates at http://fx-rates:8000/mcp"* → `register_mcp_server`
  4. *"Show me what got blocked today"* → `recent_blocks`

**Timing risk:** If running behind, **skip beat 3** (fx-rates registration) — it's the least critical.

#### Proof + Observability (7 min)
- **Slide 15:** `make verify-controls` → 16/16 (run it live if you skipped Bob)
- **Slide 16:** Three watch panes
  - ContextForge monitor (`make monitor`)
  - MCP Inspector (`make inspect-mcp`)
  - A2A Inspector (`make inspect-a2a`)
- **Key point:** "Real ecosystem tools, not custom dashboards"

#### Attendee Quickstart (7 min)
- **Slide 17:** Prerequisites (show QR code to QUICKSTART.md)
- **Slide 18:** One command: `make quickstart`
- **Slide 19:** Drive Bob (exact prompts on slide)
- **Slide 20:** Troubleshooting (UUID stale, Bob narrates, etc.)

**Attendee reality check:** Most won't finish setup during the talk. That's OK — the goal is to show them it's **one command** and give them the repo to run later.

#### Closing (5 min)
- **Slide 21:** Takeaways
  - One governed seam
  - Enforce at the bridged hook
  - Let the agent operate the plane
  - Prove it (16/16)
- **Slide 22:** CTA + QR code (larger)
  - IBM Bob trial: bob.ibm.com
  - Repo: github.com/manavgup/ai-agent-controlplane-demo
  - ContextForge: github.com/IBM/mcp-context-forge

---

## Pre-Talk Checklist (Do This Tonight)

### 1. Environment Validation
- [ ] Run `make down && make quickstart` on your presentation laptop
- [ ] Confirm `16 passed, 0 failed`
- [ ] Launch Bob (`make bob`) and run one money shot
- [ ] Open all three watch panes (monitor, inspect-mcp, inspect-a2a)
- [ ] Take screenshots of each money shot (backup if live fails)

### 2. Network Preparation
- [ ] **Pre-pull all images** on your laptop:
  ```bash
  docker compose pull
  docker compose build --pull
  ```
- [ ] Test on conference WiFi (if possible) or bring a **mobile hotspot**
- [ ] Have the repo cloned on a USB drive (backup for attendees)

### 3. Slide Deck
- [ ] Add QR codes to slides (title, prerequisites, closing)
- [ ] Test QR codes with your phone (scan from 10 feet away)
- [ ] Print speaker notes (timing + exact prompts)
- [ ] Export slides as PDF (backup if PowerPoint fails)

### 4. Demo Panes
- [ ] Arrange your screen layout (Bob + monitor + inspector)
- [ ] Increase terminal font size (readable from back of room)
- [ ] Test screen sharing (if hybrid/recorded)
- [ ] Have `make logs` and `make logs-opa` ready in tabs

### 5. Backup Plans
- [ ] Record screen captures of each money shot (play if live fails)
- [ ] Have `make verify-controls` output ready to show
- [ ] Print the QUICKSTART.md as a handout (optional)
- [ ] Test the demo on a second laptop (if available)

### 6. Attendee Materials
- [ ] Generate QR codes (`make qr-codes` if you add the target)
- [ ] Test QR code destinations on mobile
- [ ] Prepare a shortened URL (bit.ly/bob-controlplane-demo)
- [ ] Have the GitHub repo URL visible on every slide

---

## Attendee Onboarding Improvements

### Before the Session (Email/Slack)
Send attendees this checklist **24 hours before**:

```
🚀 Prepare for Tomorrow's IBM Bob × ContextForge Demo

To follow along live, please install BEFORE the session:

Required (5 min):
✓ Docker Desktop (running) — docker.com
✓ uv — docs.astral.sh/uv

Optional (to drive Bob):
✓ IBM Bob Shell — bob.ibm.com/download (30-day trial)
✓ Node.js ≥ 22.15 — nodejs.org

During the session:
1. Clone: git clone https://github.com/manavgup/ai-agent-controlplane-demo
2. Run: make quickstart
3. Follow along!

See you tomorrow!
```

### During the Session (First 5 Minutes)
- **Slide 0 (Pre-talk):** Display QR code + "Scan to get started"
- **Verbal:** "If you haven't installed Docker yet, that's OK — watch me, then run it later. The whole demo is one command: `make quickstart`."
- **Reality check:** Budget 10 minutes for attendee setup, but **don't wait** — start the talk on time and let them catch up.

### Improved README.md Additions

Add these sections to the top of README.md:

```markdown
## 🎯 New Here? Start Here

**Just want to see it work?** Run this:
```bash
git clone https://github.com/manavgup/ai-agent-controlplane-demo.git
cd ai-agent-controlplane-demo
make quickstart
```

**Want to drive Bob yourself?** Install [IBM Bob Shell](https://bob.ibm.com/download) first, then run the above.

**Stuck?** See [QUICKSTART.md](QUICKSTART.md) for detailed setup.

---
```

### Improved QUICKSTART.md Additions

Add a "Common Issues" section at the top:

```markdown
## ⚠️ Common Issues (Read This First)

| Problem | Solution |
|---------|----------|
| "Docker daemon not responding" | Start Docker Desktop (or `sudo systemctl start docker` on Linux) |
| "Port 4444 already in use" | `make down` or kill the conflicting process |
| "Bob says 'No MCP servers configured'" | You launched `bob` from the wrong directory — use `make bob` instead |
| "Bob lists no tools" | The UUID changed after reseed — run `make bob` to refresh |
| Image build fails with "Could not resolve host" | Fresh Linux VM DNS issue — see [Running on Linux](#running-on-a-fresh-linux-box--vm) |

**Still stuck?** Open an issue: [github.com/manavgup/ai-agent-controlplane-demo/issues](https://github.com/manavgup/ai-agent-controlplane-demo/issues)
```

---

## Risk Mitigation Strategies

### Risk 1: Conference WiFi Fails
**Symptoms:** Image pulls timeout, attendees can't clone repo

**Mitigation:**
1. **Pre-pull everything** on your laptop (see checklist)
2. **Bring a mobile hotspot** (test it beforehand)
3. **USB drive with repo** (clone it, zip it, bring it)
4. **Fallback:** Show your working demo, attendees run it later

**Verbal pivot:** "Conference WiFi is struggling — watch me run it, then grab the repo later. It's one command: `make quickstart`."

### Risk 2: Bob Misbehaves (Narrates Instead of Calling Tools)
**Symptoms:** Bob describes the result instead of using the tool, no gateway logs

**Mitigation:**
1. **Tell Bob explicitly:** "Use the finbyte-gateway tool to..."
2. **Check monitor Logs** — no log line = it narrated
3. **Fallback:** Switch to `make verify-controls` (16/16 proof)

**Verbal pivot:** "Bob's being chatty — let me show you the deterministic proof instead." (Run `make verify-controls`, narrate the output.)

### Risk 3: Time Runs Short
**Symptoms:** 35 minutes in, still on Act 1

**Mitigation:**
1. **Skip Act 2 beat 3** (fx-rates registration) — least critical
2. **Skip attendee setup walkthrough** — just show the QR code
3. **Compress Q&A** — take questions offline

**Verbal pivot:** "We're short on time — I'll skip the live registration and jump to the proof."

### Risk 4: Attendees Can't Keep Up
**Symptoms:** Hands raised, confused faces

**Mitigation:**
1. **Don't wait** — start the talk on time
2. **Repeat the magic command** every 5 minutes: "It's just `make quickstart`"
3. **Show the QR code** on every slide
4. **Offer office hours** after the talk

**Verbal pivot:** "If you're stuck, don't worry — the repo has everything. Scan the QR code, run `make quickstart` later, and ping me with questions."

---

## Presenter Checklist (Day Of)

### 30 Minutes Before
- [ ] Arrive early, test A/V (screen share, audio)
- [ ] Connect to conference WiFi, test speed
- [ ] Run `make down && make quickstart` (fresh start)
- [ ] Open three panes (Bob, monitor, inspector)
- [ ] Increase font sizes (terminal, browser)
- [ ] Have backup laptop ready (if available)
- [ ] Print speaker notes (timing + prompts)

### 5 Minutes Before
- [ ] Display title slide with QR code
- [ ] Run `make bob` (ready to go)
- [ ] Open monitor (`make monitor`)
- [ ] Open MCP Inspector (`make inspect-mcp`)
- [ ] Have `make verify-controls` ready in a tab
- [ ] Silence notifications (phone, laptop)

### During the Talk
- [ ] **Stick to timing** (check clock every 10 min)
- [ ] **Repeat the magic command** ("It's just `make quickstart`")
- [ ] **Show the QR code** (every 5 slides)
- [ ] **Check monitor Logs** (prove Bob called the tool)
- [ ] **Fallback to verify-controls** if Bob flakes

### After the Talk
- [ ] Take questions (5 min)
- [ ] Offer office hours (exchange contact info)
- [ ] Share the repo link one more time
- [ ] Collect feedback (what worked, what didn't)

---

## Slide-by-Slide Timing Guide

| Slide | Content | Time | Cumulative | Notes |
|-------|---------|------|------------|-------|
| 1 | Title + QR | 1 min | 1 min | Let attendees scan |
| 2 | Problem | 1 min | 2 min | Hook: "$50k wire" |
| 3 | MCP vs A2A | 1 min | 3 min | Quick context |
| 4 | The cast | 2 min | 5 min | Name the players |
| 5 | Architecture | 3 min | 8 min | Diagram + enforcement point |
| 6 | Money Shot #1 (Policy) | 3 min | 11 min | Live Bob: $50k blocked |
| 7 | Money Shot #2 (PII) | 2 min | 13 min | Live Bob: redacted |
| 8 | Money Shot #3 (Injection) | 2 min | 15 min | Live Bob: neutralized |
| 9 | Money Shot #4 (RBAC) | 3 min | 18 min | Live Bob + Inspector |
| 10 | Act 2 intro | 1 min | 19 min | Persona switch |
| 11-14 | Operator beats | 8 min | 27 min | 2 min each (skip #3 if behind) |
| 15 | Proof (16/16) | 2 min | 29 min | Run verify-controls |
| 16 | Observability tools | 3 min | 32 min | Show monitor/inspectors |
| 17-20 | Attendee quickstart | 7 min | 39 min | Prerequisites + one command |
| 21 | Takeaways | 3 min | 42 min | Four key points |
| 22 | CTA + QR | 1 min | 43 min | Scan to get started |
| — | Q&A | 5 min | 48 min | Take questions |
| — | Buffer | 2 min | 50 min | Overflow / wrap up |

**If running behind at 30 min:** Skip Act 2 beat 3 (fx-rates) and compress attendee walkthrough to 3 min (just show QR code).

---

## Post-Talk Follow-Up

### Immediate (Next Day)
- [ ] Share slides + recording (if recorded)
- [ ] Post repo link on conference Slack/Discord
- [ ] Respond to GitHub issues (attendees will open them)
- [ ] Write a blog post (optional)

### Within a Week
- [ ] Collect feedback (survey or informal)
- [ ] Update README with common issues (from attendee questions)
- [ ] Add a "Conference Talks" section to README (link to slides)
- [ ] Consider a YouTube walkthrough (if there's demand)

---

## Key Talking Points (Memorize These)

1. **The hook:** "We handed an AI agent the keys to a fintech payments system. Watch what happens when it tries to wire $50,000."

2. **The thesis:** "When an agent can move money, the question isn't 'can it do it?' — it's 'who's in charge?'"

3. **The magic command:** "It's one command: `make quickstart`. That's it."

4. **The proof:** "We don't just show you the controls — we prove them. 16 assertions, deterministic, headless."

5. **The cross-language moment:** "That Python agent just tried to delegate a $50k payment to a Rust agent. The gateway blocked it at the bridged hook."

6. **The operator twist:** "Now watch Bob operate the control plane itself. Same agent, different RBAC scope."

7. **The ecosystem validation:** "We're not using custom dashboards — these are the real tools: ContextForge's monitor, MCP Inspector, A2A Inspector."

8. **The CTA:** "Try it yourself. Scan the QR code, run `make quickstart`, and you'll have a governed agent mesh in 2 minutes."

---

## Emergency Contacts & Resources

**If something breaks:**
- ContextForge docs: https://github.com/IBM/mcp-context-forge
- MCP Inspector: https://github.com/modelcontextprotocol/inspector
- A2A Inspector: https://github.com/a2aproject/a2a-inspector
- IBM Bob docs: https://bob.ibm.com/docs

**If attendees need help:**
- GitHub Issues: https://github.com/manavgup/ai-agent-controlplane-demo/issues
- Your contact: [Add your email/Slack]

---

## Final Confidence Boosters

**You have:**
✅ A working demo (16/16 proof)  
✅ Comprehensive docs (README, QUICKSTART, RUNBOOK)  
✅ Real ecosystem tools (not custom dashboards)  
✅ Cross-language proof (Python → Rust)  
✅ One-command setup (`make quickstart`)  
✅ Deterministic proof (works without Bob)  
✅ Multiple fallback plans (verify-controls, screen captures)

**You're ready.** The demo is solid. The docs are excellent. The story is compelling. Trust your preparation.

**Remember:** Even if Bob misbehaves or WiFi fails, you can **prove every control** with `make verify-controls`. The demo can't fully fail — you have multiple layers of proof.

**Good luck tomorrow! 🚀**
