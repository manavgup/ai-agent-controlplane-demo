"""Unit tests for the pure room-voter logic (no a2a-sdk, no network)."""

from vote import (
    LENIENT_THRESHOLD,
    STRICT_THRESHOLD,
    decide_vote,
    vote_expense,
)
from vote import parse_threshold, parse_owner, vote_with_corpus, decide_with_corpus


def test_strict_rejects_the_50k_finale():
    assert vote_expense(50000, "strict")[0] == "reject"


def test_strict_approves_a_small_wire():
    assert vote_expense(500, "strict")[0] == "approve"


def test_strict_threshold_is_inclusive():
    assert vote_expense(STRICT_THRESHOLD, "strict")[0] == "reject"
    assert vote_expense(STRICT_THRESHOLD - 1, "strict")[0] == "approve"


def test_lenient_approves_the_50k_finale():
    assert vote_expense(50000, "lenient")[0] == "approve"


def test_lenient_rejects_the_implausibly_large():
    assert vote_expense(LENIENT_THRESHOLD, "lenient")[0] == "reject"


def test_random_is_deterministic_per_seed():
    assert vote_expense(50000, "random", seed="room-random-1") == vote_expense(
        50000, "random", seed="room-random-1"
    )


def test_random_reaches_both_outcomes_across_seeds():
    outcomes = {vote_expense(50000, "random", seed=f"room-{i}")[0] for i in range(20)}
    assert outcomes == {"approve", "reject"}


def test_unknown_stance_falls_back_to_random():
    assert vote_expense(50000, "banana", seed="x") == vote_expense(
        50000, "random", seed="x"
    )


def test_decide_vote_strict_rejects_50k():
    out = decide_vote(
        "Vote on expense. payee=Acme LLC amount=50000 approval=false "
        "stance=strict agent=room-strict-1."
    )
    assert out.startswith("VOTE=reject ::")


def test_decide_vote_lenient_approves_50k():
    out = decide_vote("amount=50000 approval=false stance=lenient agent=room-lenient-1")
    assert out.startswith("VOTE=approve ::")


def test_decide_vote_defaults_to_random_when_stance_missing():
    out = decide_vote("amount=50000 agent=room-x")
    assert out.split(" ")[0] in ("VOTE=approve", "VOTE=reject")


def test_parse_threshold_forms():
    assert parse_threshold("reject over $20,000") == 20000
    assert parse_threshold("cap 20k") == 20000
    assert parse_threshold("approve up to $5000") == 5000
    assert parse_threshold("no numbers here") is None


def test_parse_owner():
    assert parse_owner("amount=50000 stance=strict agent=room-strict-MG") == "MG"
    assert (
        parse_owner("agent=room-lenient-AB-2") == "AB"
    )  # suffix stripped is fine if MG; AB here
    assert parse_owner("agent=room-strict-1") == "1"  # fixed voter -> numeric


def test_corpus_threshold_rejects_over_cap():
    v, _ = vote_with_corpus(50000, "lenient", "room-x", "reject over $20000")
    assert v == "reject"


def test_corpus_threshold_approves_under_cap():
    v, _ = vote_with_corpus(5000, "strict", "room-x", "reject over $20000")
    assert v == "approve"


def test_corpus_keyword_without_number():
    assert (
        vote_with_corpus(50000, "strict", "room-x", "approve everything")[0]
        == "approve"
    )
    assert vote_with_corpus(500, "lenient", "room-x", "always reject")[0] == "reject"


def test_no_note_falls_back_to_stance():
    assert vote_with_corpus(50000, "strict", "room-x", "") == vote_expense(
        50000, "strict", "room-x"
    )
    assert vote_with_corpus(50000, "lenient", "room-x", "   ") == vote_expense(
        50000, "lenient", "room-x"
    )


def test_decide_with_corpus_emits_token():
    out = decide_with_corpus(
        "amount=50000 stance=strict agent=room-strict-MG", "reject over $20000"
    )
    assert out.startswith("VOTE=reject ::")


def test_parse_owner_strips_trailing_period():
    # the chair/companion prompt ends "... agent=room-strict-MG."
    assert parse_owner("amount=50000 stance=strict agent=room-strict-MG.") == "MG"
    assert parse_owner("agent=room-strict-1.") == "1"


def test_parse_threshold_ignores_masked_card_prefers_dollar():
    # PII-redacted note: the masked card's last 4 must not become the cap
    note = "my card ****-****-****-1111, reject anything over $20,000"
    assert parse_threshold(note) == 20000
