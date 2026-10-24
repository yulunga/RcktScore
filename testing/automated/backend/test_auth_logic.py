from werkzeug.security import generate_password_hash

from common import auth_logic


def membership_row(row_id, organization_id, organization_type, password_hash, approval_status="approved"):
    return {
        "id": row_id,
        "clubusername": "player@example.com",
        "password_hash": password_hash,
        "organization_id": organization_id,
        "role": "admin" if organization_type == "personal" else "user",
        "approval_status": approval_status,
        "org_type": organization_type,
        "plan": "personal_plus" if organization_type == "personal" else "club_essentials",
        "organization_name": "Player Personal" if organization_type == "personal" else "Example Club",
        "enabled_sports": ["squash"],
        "enabled_sports_web": ["squash"],
        "enabled_sports_ios": ["squash"],
        "platform_enabled_sports_web": ["squash"],
        "platform_enabled_sports_ios": ["squash"],
        "user_json": {},
    }


def test_identity_password_retains_every_approved_membership(monkeypatch):
    rows = [
        membership_row(1, 42, "club", generate_password_hash("current-password")),
        membership_row(2, 99, "personal", generate_password_hash("older-password")),
    ]
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)

    result = auth_logic.authenticate_org_user_memberships(
        object(),
        "player@example.com",
        "current-password",
        client_type="web_app",
    )

    assert [membership["organization_id"] for membership in result["approved_memberships"]] == [42, 99]
    assert result["approved_memberships"][1]["organization_type"] == "personal"


def test_identity_rejects_password_that_matches_no_membership(monkeypatch):
    rows = [membership_row(1, 42, "club", generate_password_hash("current-password"))]
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)

    result = auth_logic.authenticate_org_user_memberships(
        object(),
        "player@example.com",
        "wrong-password",
    )

    assert result == {"approved_memberships": [], "pending_memberships": []}
