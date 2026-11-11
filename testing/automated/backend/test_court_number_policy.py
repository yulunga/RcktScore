import pytest

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
