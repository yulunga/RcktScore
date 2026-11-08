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


def test_identity_password_must_match_every_membership_and_self_heals(monkeypatch):
    rows = [
        membership_row(1, 42, "club", generate_password_hash("shared-password")),
        membership_row(2, 99, "personal", generate_password_hash("shared-password")),
    ]
    synchronized = []
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)
    monkeypatch.setattr(
        auth_logic,
        "_synchronize_identity_password_hash",
        lambda connection, username, password: synchronized.append((connection, username, password)),
    )
    connection = object()

    result = auth_logic.authenticate_org_user_memberships(
        connection,
        "player@example.com",
        "shared-password",
        client_type="web_app",
    )

    assert [membership["organization_id"] for membership in result["approved_memberships"]] == [42, 99]
    assert result["approved_memberships"][1]["organization_type"] == "personal"
    assert synchronized == [(connection, "player@example.com", "shared-password")]


def test_identity_rejects_partial_password_match_and_requires_reset(monkeypatch):
    rows = [
        membership_row(1, 42, "club", generate_password_hash("current-password")),
        membership_row(2, 99, "personal", generate_password_hash("older-password")),
    ]
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)

    try:
        auth_logic.authenticate_org_user_memberships(object(), "player@example.com", "current-password")
    except auth_logic.IdentityPasswordResetRequired:
        pass
    else:
        raise AssertionError("A partial identity password match must require a reset")


def test_null_password_membership_is_returned_after_valid_identity_password(monkeypatch):
    password_hash = generate_password_hash("shared-password")
    rows = [
        membership_row(1, 42, "club", password_hash),
        membership_row(2, 99, "personal", None),
    ]
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)

    result = auth_logic.authenticate_org_user_memberships(object(), "player@example.com", "shared-password")

    assert [membership["organization_id"] for membership in result["approved_memberships"]] == [42, 99]


def test_identity_rejects_password_that_matches_no_membership(monkeypatch):
    rows = [membership_row(1, 42, "club", generate_password_hash("current-password"))]
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)

    result = auth_logic.authenticate_org_user_memberships(
        object(),
        "player@example.com",
        "wrong-password",
    )

    assert result == {"approved_memberships": [], "pending_memberships": []}


def test_identity_with_valid_password_cannot_login_while_deletion_is_pending(monkeypatch):
    password_hash = generate_password_hash("shared-password")
    rows = [membership_row(2, 99, "personal", password_hash)]
    rows[0]["deletion_requested_at"] = "2026-11-08T00:00:00+00:00"
    monkeypatch.setattr(auth_logic, "get_org_users", lambda *_args: rows)

    try:
        auth_logic.authenticate_org_user_memberships(object(), "player@example.com", "shared-password")
    except auth_logic.AccountDeletionPending:
        pass
    else:
        raise AssertionError("Deletion-pending identity must not be able to create a session")
