import pytest

from common.match_watch_logic import MatchWatchError, ensure_personal_plus, normalize_watch_code


def test_normalize_watch_code_accepts_human_spacing_and_case():
    assert normalize_watch_code(" abcd-2345 ") == "ABCD2345"


def test_personal_plus_can_use_remote_match_viewing():
    ensure_personal_plus({"organization_type": "personal", "plan": "personal_plus"})


@pytest.mark.parametrize(
    "membership",
    [
        {"organization_type": "personal", "plan": "personal_free"},
        {"organization_type": "club", "plan": "club_pro"},
    ],
)
def test_remote_match_viewing_rejects_non_personal_plus_memberships(membership):
    with pytest.raises(MatchWatchError) as raised:
        ensure_personal_plus(membership)

    assert raised.value.code == "PERSONAL_PLUS_REQUIRED"
