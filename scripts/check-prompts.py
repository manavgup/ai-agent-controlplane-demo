#!/usr/bin/env python3
"""check-prompts: assert the static surfaces still match the canonical drive prompts.

The companion (companion/app.py) and `make connect` (scripts/connect.sh) READ
docs/assets/prompts.json at runtime, so they can't drift. The static docs embed
copies (for offline/copy-paste), so this guard fails if any canonical prompt is
missing from a surface that's supposed to carry all three.

Run: make check-prompts   (also a good pre-commit / CI gate)
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "assets", "prompts.json")

# Surfaces that must contain ALL three drive prompts verbatim.
SURFACES = [
    "docs/build.html",
    "docs/path-bob.html",
    "docs/path-diy.html",
    "docs/dev-day-runsheet.md",
    "companion/app.py",  # the hardcoded fallback list
]


def main():
    says = [p["say"] for p in json.load(open(SRC))["drive"]]
    missing = []
    for rel in SURFACES:
        path = os.path.join(ROOT, rel)
        try:
            text = open(path, encoding="utf-8").read()
        except OSError as e:
            missing.append(f"{rel}: cannot read ({e})")
            continue
        for say in says:
            if say not in text:
                missing.append(f"{rel}: missing prompt -> {say!r}")

    if missing:
        print("✗ drive prompts out of sync with docs/assets/prompts.json:\n")
        for m in missing:
            print("  " + m)
        print(
            "\nFix: update the surface(s) above to the canonical wording, "
            "or edit docs/assets/prompts.json if the canonical set changed."
        )
        return 1
    print(
        f"✓ all {len(SURFACES)} surfaces carry the {len(says)} canonical drive prompts"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
