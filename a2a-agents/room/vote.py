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


def parse_threshold(note):
    """First dollar figure in the note -> float (handles $, commas, trailing k).
    Returns None if there is no number."""
    m = re.search(r"\$?\s*([\d][\d,]*(?:\.\d+)?)\s*([kK])?", note or "")
    if not m:
        return None
    val = float(m.group(1).replace(",", ""))
    if m.group(2):  # 20k -> 20000
        val *= 1000
    return val


def parse_owner(text):
    """Owner initials from the agent name: room-<stance>-<initials> -> <initials>.
    Fixed voters (room-strict-1) yield the numeric suffix."""
    name = parse_seed(text)  # e.g. room-strict-MG  (or room-lenient-AB-2)
    parts = name.split("-")
    return parts[2] if len(parts) >= 3 else ""


def vote_with_corpus(amount, stance, seed, note):
    """Vote per the owner's note when it states a rule; otherwise fall back to stance.

    Precedence: an explicit dollar cap (reject if amount >= cap) beats a bare
    approve/reject keyword; with no usable rule, defer to the stance.
    """
    note = (note or "").strip()
    if note:
        try:
            amt = float(amount)
        except (TypeError, ValueError):
            amt = 0.0
        thr = parse_threshold(note)
        if thr is not None:
            if amt >= thr:
                return "reject", f"owner's note: cap ${thr:,.0f}, ${amt:,.0f} is over"
            return "approve", f"owner's note: ${amt:,.0f} under cap ${thr:,.0f}"
        lowered = note.lower()
        if any(k in lowered for k in ("reject", "block", "deny", "no ")):
            return "reject", "owner's note says reject"
        if any(k in lowered for k in ("approve", "allow", "yes")):
            return "approve", "owner's note says approve"
    return vote_expense(amount, stance, seed)


def decide_with_corpus(text, note):
    """message text + the owner's (governed) note -> 'VOTE=... :: reason'."""
    vote, reason = vote_with_corpus(
        parse_amount(text), parse_stance(text), parse_seed(text), note
    )
    return f"VOTE={vote} :: {reason}"
