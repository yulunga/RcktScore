from datetime import datetime, timezone

from werkzeug.security import check_password_hash

from common import password_reset_logic


class RecordingCursor:
    def __init__(self, token):
        self.token = token
        self.executions = []
        self._fetch_count = 0

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, query, params):
        self.executions.append((" ".join(query.split()), params))

    def fetchone(self):
        self._fetch_count += 1
        if self._fetch_count == 1:
            return {
                "clubusername": "player@example.com",
                "password_reset_requested_at": datetime.now(timezone.utc),
            }
        return None


class RecordingConnection:
    def __init__(self, token):
        self.cursor_instance = RecordingCursor(token)
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True


def test_normal_reset_updates_all_passwords_without_approving_pending_memberships(monkeypatch):
    connection = RecordingConnection("reset-token")
    revoked = []
    monkeypatch.setattr(
        password_reset_logic,
        "revoke_active_sessions_for_username",
        lambda _connection, username, reason: revoked.append((username, reason)),
    )

    password_reset_logic.confirm_password_reset(connection, "reset-token", "Copper!Falcon9")

    statements = [query for query, _params in connection.cursor_instance.executions]
    assert not any("SET approval_status" in query for query in statements)
    assert not any('UPDATE "HitnScoreInterestRequests"' in query for query in statements)
    identity_update = next((params for query, params in connection.cursor_instance.executions if "SET password_hash" in query), None)
    assert identity_update is not None
    assert identity_update["username"] == "player@example.com"
    assert check_password_hash(identity_update["password_hash"], "Copper!Falcon9")
    assert revoked == [("player@example.com", "password_reset")]
    assert connection.committed is True


def test_first_account_setup_approves_only_the_token_holding_membership(monkeypatch):
    connection = RecordingConnection("setup-token")
    monkeypatch.setattr(password_reset_logic, "revoke_active_sessions_for_username", lambda *_args, **_kwargs: None)

    password_reset_logic.confirm_password_reset(connection, "setup_token-value", "Copper!Falcon9")

    approval_query, approval_params = next(
        (query, params)
        for query, params in connection.cursor_instance.executions
        if "SET approval_status" in query
    )
    assert "password_reset_token = %(reset_token)s" in approval_query
    assert approval_params["reset_token"] == "setup_token-value"
    assert any("SET password_hash" in query for query, _params in connection.cursor_instance.executions)
