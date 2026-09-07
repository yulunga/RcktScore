from datetime import datetime, timezone

from common.root_admin_logic import _serialize_root_admin_user_summary


def membership_row(**overrides):
    row = {
        "membership_id": 1,
        "clubusername": "player@example.com",
        "first_name": "Test",
        "surname": "Player",
        "created_at": datetime(2026, 1, 1, tzinfo=timezone.utc),
        "approval_status": "approved",
        "org_type": "personal",
        "plan": "personal_free",
        "interest_request_id": 10,
        "email_validated": True,
    }
    row.update(overrides)
    return row


def test_personal_user_is_unverified_until_email_validation_completes():
    user = _serialize_root_admin_user_summary(
        "player@example.com",
        [membership_row(approval_status="pending", email_validated=False)],
    )

    assert user["email_verified"] is False
    assert user["unverified_membership_count"] == 1


def test_personal_user_is_verified_after_password_link_completion():
    user = _serialize_root_admin_user_summary("player@example.com", [membership_row()])

    assert user["email_verified"] is True
    assert user["unverified_membership_count"] == 0


def test_approved_club_user_without_personal_registration_is_verified():
    user = _serialize_root_admin_user_summary(
        "club-player@example.com",
        [
            membership_row(
                org_type="club",
                plan="club_essentials",
                interest_request_id=None,
                email_validated=None,
            )
        ],
    )

    assert user["email_verified"] is True
