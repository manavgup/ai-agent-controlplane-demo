# QR Code Setup for Conference Talk

## Quick Access Solutions

### Option 1: GitHub Repo QR Code (Recommended)
**Best for:** Attendees who want to clone and run the demo themselves

Create a QR code pointing to: `https://github.com/manavgup/ai-agent-controlplane-demo`

**Advantages:**
- Direct access to the full codebase
- Attendees can star/fork the repo
- Access to issues/discussions for follow-up questions
- Works offline once cloned

**Where to place it:**
- First slide (title slide)
- Last slide (takeaway/CTA slide)
- Printed handouts
- Embedded in README.md

### Option 2: Quickstart Landing Page QR Code
**Best for:** Fastest path to running demo

Create a shortened URL pointing to the QUICKSTART.md:
`https://github.com/manavgup/ai-agent-controlplane-demo/blob/main/QUICKSTART.md`

**Advantages:**
- Attendees land directly on setup instructions
- No navigation needed
- Mobile-friendly view of prerequisites

### Option 3: Multi-Destination QR Code Strategy
**Best for:** Different audience segments

Create **three QR codes** for different slides:

1. **Intro Slide:** Repo homepage
   - `https://github.com/manavgup/ai-agent-controlplane-demo`
   
2. **Prerequisites Slide:** QUICKSTART.md
   - `https://github.com/manavgup/ai-agent-controlplane-demo/blob/main/QUICKSTART.md`
   
3. **Closing Slide:** IBM Bob trial + repo
   - Create a simple landing page or use a link aggregator (e.g., Linktree, bio.link)
   - Links to: IBM Bob trial, GitHub repo, ContextForge docs

## Implementation Steps

### 1. Generate QR Codes

**Using Python (included in repo):**

```bash
# Install qrcode library
pip install qrcode[pil]

# Generate QR code
python3 << 'EOF'
import qrcode

# Main repo QR code
qr = qrcode.QRCode(version=1, box_size=10, border=5)
qr.add_data('https://github.com/manavgup/ai-agent-controlplane-demo')
qr.make(fit=True)
img = qr.make_image(fill_color="black", back_color="white")
img.save('slides/assets/qr-repo.png')

# Quickstart QR code
qr2 = qrcode.QRCode(version=1, box_size=10, border=5)
qr2.add_data('https://github.com/manavgup/ai-agent-controlplane-demo/blob/main/QUICKSTART.md')
qr2.make(fit=True)
img2 = qr2.make_image(fill_color="black", back_color="white")
img2.save('slides/assets/qr-quickstart.png')

print("QR codes generated in slides/assets/")
EOF
```

**Using Online Tools:**
- QR Code Generator: https://www.qr-code-generator.com/
- QR Code Monkey: https://www.qrcode-monkey.com/
- Canva QR Code Generator (with branding): https://www.canva.com/qr-code-generator/

### 2. Add to PowerPoint Slides

**Recommended placement:**

```
Slide 1 (Title):
  - Bottom right corner
  - Text: "Scan to access demo repo"
  - Size: 1.5" x 1.5"

Slide 14 (Takeaways/CTA):
  - Larger, center-right
  - Text: "Try it yourself: scan to get started"
  - Size: 2" x 2"

Slide 15 (Prerequisites - Follow-along section):
  - Top right corner
  - Text: "Scan for setup guide"
  - Size: 1.5" x 1.5"
```

### 3. Create Shortened URLs (Optional)

For cleaner QR codes and tracking:

```bash
# Using bit.ly, tinyurl, or your organization's URL shortener
# Example:
# https://github.com/manavgup/ai-agent-controlplane-demo
# → https://bit.ly/bob-controlplane-demo
```

**Benefits:**
- Cleaner, simpler QR codes
- Can track scan analytics
- Can update destination without regenerating QR code

### 4. Test QR Codes

**Before the talk:**
- [ ] Test with multiple phone cameras (iOS, Android)
- [ ] Test from different distances (back of room)
- [ ] Verify destination loads quickly on mobile
- [ ] Check mobile rendering of QUICKSTART.md

## Alternative: Conference-Specific Landing Page

If you have time, create a simple landing page at `docs/conference-landing.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>IBM Bob × ContextForge Demo</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; max-width: 600px; margin: 50px auto; padding: 20px; }
        .button { display: block; padding: 15px; margin: 10px 0; background: #0F62FE; 
                  color: white; text-decoration: none; border-radius: 5px; text-align: center; }
        h1 { color: #0F62FE; }
    </style>
</head>
<body>
    <h1>🤖 IBM Bob × ContextForge</h1>
    <p>AI Agent Control Plane Demo</p>
    
    <a href="https://github.com/manavgup/ai-agent-controlplane-demo" class="button">
        📦 Get the Demo Code
    </a>
    
    <a href="https://github.com/manavgup/ai-agent-controlplane-demo/blob/main/QUICKSTART.md" class="button">
        🚀 Quick Start Guide
    </a>
    
    <a href="https://bob.ibm.com/download" class="button">
        💻 Download IBM Bob Shell
    </a>
    
    <a href="https://github.com/IBM/mcp-context-forge" class="button">
        🔧 ContextForge Project
    </a>
</body>
</html>
```

Host this on GitHub Pages and point the QR code to it.

## Makefile Integration

Add to your Makefile:

```makefile
.PHONY: qr-codes
qr-codes: ## Generate QR codes for conference materials
	@echo "Generating QR codes..."
	@pip install -q qrcode[pil]
	@python3 -c "import qrcode; \
		qr = qrcode.QRCode(version=1, box_size=10, border=5); \
		qr.add_data('https://github.com/manavgup/ai-agent-controlplane-demo'); \
		qr.make(fit=True); \
		qr.make_image(fill_color='black', back_color='white').save('slides/assets/qr-repo.png'); \
		print('✓ QR code saved to slides/assets/qr-repo.png')"
```

Then run: `make qr-codes`

## Recommended Strategy for Your Talk

**For a 50-minute talk with live attendee participation:**

1. **Title Slide:** QR code to main repo
   - Text: "Scan now to follow along"
   - Gives attendees time to scan while you introduce yourself

2. **Prerequisites Slide (Part B, Slide 15):** QR code to QUICKSTART.md
   - Text: "Setup guide"
   - Direct path to installation instructions

3. **Closing Slide:** QR code to repo + verbal CTA
   - Text: "Try it yourself: make quickstart"
   - Reinforce the one-command setup

4. **Printed Handout (Optional):**
   - Single-page cheat sheet with:
     - QR code to repo
     - Prerequisites checklist
     - The magic command: `make quickstart`
     - Your contact info for questions

## Testing Checklist

Before the conference:
- [ ] Generate QR codes
- [ ] Add to PowerPoint slides
- [ ] Test scanning from 10+ feet away
- [ ] Verify mobile rendering of destination pages
- [ ] Print test handout (if using)
- [ ] Have backup: display URL on slide as text too
