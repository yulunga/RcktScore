from common.access_control import (
    CAPABILITY_CLUB_MEMBERS_READ,
    CAPABILITY_MATCH_MANAGE,
    CAPABILITY_MATCH_READ,
    membership_has_capability,
    normalize_membership_role,
)
from common.tournament.tournament_logic import redact_tournament_private_fields


def club_membership(role):
    return {"role": role, "organization_type": "club"}


def test_legacy_user_role_maps_to_scorer_without_losing_match_access():
    assert normalize_membership_role("user") == "scorer"
    assert membership_has_capability(club_membership("user"), CAPABILITY_MATCH_MANAGE)


def test_read_only_can_view_but_cannot_mutate_matches():
    membership = club_membership("read_only")

    assert membership_has_capability(membership, CAPABILITY_MATCH_READ)
    assert not membership_has_capability(membership, CAPABILITY_MATCH_MANAGE)


def test_only_admin_can_read_the_private_member_directory():
    assert membership_has_capability(club_membership("admin"), CAPABILITY_CLUB_MEMBERS_READ)
    assert not membership_has_capability(club_membership("scorer"), CAPABILITY_CLUB_MEMBERS_READ)
    assert not membership_has_capability(club_membership("read_only"), CAPABILITY_CLUB_MEMBERS_READ)


def test_personal_workspace_owner_keeps_match_management_access():
    membership = {"role": "scorer", "organization_type": "personal"}

    assert membership_has_capability(membership, CAPABILITY_MATCH_MANAGE)
    assert membership_has_capability(membership, CAPABILITY_CLUB_MEMBERS_READ)


def test_member_tournament_response_redacts_guest_contact_and_account_ids():
    tournament = {
        "id": "tournament-1",
        "entries": [{
            "id": "entry-1",
            "display_name": "Guest Player",
            "email": "guest@example.com",
            "registered_username": "guest@example.com",
            "user_id": "identity-1",
            "relationship": "guest",
        }],
    }

    redacted = redact_tournament_private_fields(tournament)

    assert redacted["entries"] == [{
        "id": "entry-1",
        "display_name": "Guest Player",
        "relationship": "guest",
    }]
    assert tournament["entries"][0]["email"] == "guest@example.com"
