"""Unit tests for the pure room-voter logic (no a2a-sdk, no network)."""

from vote import (
    LENIENT_THRESHOLD,
    STRICT_THRESHOLD,
    decide_vote,
    vote_expense,
)


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
