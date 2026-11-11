from common.sport_config import (
    client_sport_field,
    court_sport_id,
    court_supports_match,
    effective_enabled_sports,
    normalize_sport_client,
)


def test_client_aliases_select_the_expected_membership_field():
    assert normalize_sport_client("ios") == "mobile_app"
    assert normalize_sport_client("mobile_app") == "mobile_app"
    assert normalize_sport_client("browser") == "web_app"
    assert client_sport_field("ios_app") == "enabled_sports_ios"
    assert client_sport_field("web_app") == "enabled_sports_web"


def test_effective_access_intersects_platform_organization_and_membership():
    assert effective_enabled_sports(
        ["squash", "racketball", "tennis", "padel"],
        ["squash", "tennis", "padel"],
        ["tennis", "padel"],
    ) == ["tennis", "padel"]


def test_missing_membership_override_inherits_the_organization_access():
    assert effective_enabled_sports(
        ["squash", "tennis"],
        ["squash", "racketball", "tennis"],
        None,
    ) == ["squash", "tennis"]


def test_racketball_uses_the_squash_physical_court_category():
    assert court_sport_id("racketball") == "squash"
    assert court_supports_match("squash", "racketball") is True
    assert court_supports_match("racketball", "squash") is True
    assert court_supports_match("tennis", "racketball") is False
    assert court_supports_match(None, "racketball") is True
