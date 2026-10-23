from functions.login.handler import default_identity_membership, identity_first_login_enabled


def test_identity_first_login_defaults_on(monkeypatch):
    monkeypatch.delenv("IDENTITY_FIRST_LOGIN_ENABLED", raising=False)
    assert identity_first_login_enabled() is True


def test_identity_first_login_can_restore_legacy_chooser(monkeypatch):
    monkeypatch.setenv("IDENTITY_FIRST_LOGIN_ENABLED", "false")
    assert identity_first_login_enabled() is False


def test_identity_session_prefers_personal_membership():
    club = {"id": 1, "organization_type": "club"}
    personal = {"id": 2, "organization_type": "personal"}
    assert default_identity_membership([club, personal]) == personal


def test_identity_session_uses_first_membership_without_personal_account():
    first_club = {"id": 1, "organization_type": "club"}
    second_club = {"id": 2, "organization_type": "club"}
    assert default_identity_membership([first_club, second_club]) == first_club
