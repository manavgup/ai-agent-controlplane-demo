"""Pure voting logic for the room A2A voter agents.

No network, no a2a-sdk import, so it unit-tests in isolation and is deterministic
on stage (no wall-clock / random entropy). agent_executor.py wraps decide_vote().
"""

import hashlib
import re

# Demo knobs (amount-driven so the agent tally is intuitive for a finance room).
STRICT_THRESHOLD = 10_000  # strict agents reject wires >= this (matches OPA cap)
LENIENT_THRESHOLD = 100_000  # lenient agents reject only the truly implausible


def vote_expense(amount, stance, seed=""):
    """Return (vote, reason); vote is 'approve' or 'reject'.

    strict  — reject if amount >= STRICT_THRESHOLD
    lenient — reject only if amount >= LENIENT_THRESHOLD
    random  — deterministic ~50/50 from hash(seed, amount)
    Unknown stance falls back to 'random'.
    """
    stance = (stance or "random").strip().lower()
    try:
        amount = float(amount)
    except (TypeError, ValueError):
        amount = 0.0

    if stance == "strict":
        if amount >= STRICT_THRESHOLD:
            return "reject", f"strict: ${amount:,.0f} >= ${STRICT_THRESHOLD:,} cap"
        return "approve", f"strict: ${amount:,.0f} under ${STRICT_THRESHOLD:,} cap"

    if stance == "lenient":
        if amount >= LENIENT_THRESHOLD:
            return "reject", f"lenient: ${amount:,.0f} is implausibly large"
        return "approve", f"lenient: ${amount:,.0f} looks fine"

    digest = hashlib.sha256(f"{seed}:{amount:.0f}".encode()).hexdigest()
    if int(digest[:8], 16) % 2 == 0:
        return "approve", "random: coin landed approve"
    return "reject", "random: coin landed reject"


def parse_amount(text):
    m = re.search(r"amount=\$?([\d,]+(?:\.\d+)?)", text)
    if not m:
        m = re.search(r"\$?\s*(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)", text)
    return float(m.group(1).replace(",", "")) if m else 0.0


def parse_stance(text):
    m = re.search(r"stance=(\w+)", text, re.IGNORECASE)
    return m.group(1).lower() if m else "random"


def parse_seed(text):
    m = re.search(r"agent=([\w.-]+)", text)
    return m.group(1) if m else ""


def decide_vote(text):
    """message text -> 'VOTE=<approve|reject> :: <reason>' (grep-friendly token)."""
    text = text or ""
    vote, reason = vote_expense(
        parse_amount(text), parse_stance(text), seed=parse_seed(text)
    )
    return f"VOTE={vote} :: {reason}"
