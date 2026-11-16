import pytest

import common.organization_logic as organization_logic
from common.organization_logic import _normalized_court_number


def test_club_essentials_normalizes_a_selected_court_number():
    assert _normalized_court_number("court 2", "club_essentials") == "Court-2"


@pytest.mark.parametrize("value", ["Centre Court", "Court-6"])
def test_club_essentials_rejects_numbers_outside_its_five_court_range(value):
    with pytest.raises(ValueError, match="Court-1 to Court-5"):
        _normalized_court_number(value, "club_essentials")


def test_club_pro_accepts_twenty_five_courts_per_sport():
    assert _normalized_court_number("Court-25", "club_pro") == "Court-25"

    with pytest.raises(ValueError, match="Court-1 to Court-25"):
        _normalized_court_number("Court-26", "club_pro")


def test_future_premium_plan_keeps_free_text_court_numbers():
    assert _normalized_court_number("Show Court", "club_premium") == "Show Court"


def test_create_court_rejects_duplicate_customer_facing_name(monkeypatch):
    monkeypatch.setattr(organization_logic, "_court_plan", lambda *_args: "club_essentials")
    monkeypatch.setattr(organization_logic, "_court_number_exists", lambda *_args, **_kwargs: False)
    monkeypatch.setattr(organization_logic, "_court_alias_exists", lambda *_args, **_kwargs: True)

    with pytest.raises(ValueError, match="already used as a court name for Squash"):
        organization_logic.create_court(
            object(),
            12,
            "Court-2",
            "Championship Court",
            "squash",
        )


def test_duplicate_racketball_court_is_reported_as_squash(monkeypatch):
    monkeypatch.setattr(organization_logic, "_court_plan", lambda *_args: "club_essentials")
    monkeypatch.setattr(organization_logic, "_court_number_exists", lambda *_args, **_kwargs: True)

    with pytest.raises(ValueError, match="Court-1 already exists for Squash"):
        organization_logic.create_court(object(), 12, "Court-1", "Court-1", "racketball")


def test_database_alias_collision_has_clear_message():
    error = type("Duplicate", (), {"diag": type("Diag", (), {"constraint_name": "uq_skwshcourts_org_sport_alias"})()})()

    assert organization_logic._court_unique_violation_message(
        error,
        "Court-2",
        "Championship Court",
        "tennis",
    ) == "Championship Court is already used as a court name for Tennis"
