import pytest

from common import root_admin_logic
from common import session_logic


class RecordingCursor:
    def __init__(self, connection):
        self.connection = connection
        self.last_statement = ""

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params=None):
        self.last_statement = statement
        self.connection.statements.append((statement, params or {}))

    def fetchone(self):
        if "SELECT clubusername" in self.last_statement:
            return {"clubusername": "player@example.com"}
        return None


class RecordingConnection:
    def __init__(self):
        self.statements = []
        self.commit_count = 0

    def cursor(self):
        return RecordingCursor(self)

    def commit(self):
        self.commit_count += 1


def test_root_admin_password_change_hashes_all_memberships_and_revokes_sessions(monkeypatch):
    connection = RecordingConnection()
    revoked = []
    monkeypatch.setattr(root_admin_logic, "generate_password_hash", lambda password: f"hash:{password}")
    monkeypatch.setattr(
        session_logic,
        "revoke_active_sessions_for_username",
        lambda current_connection, username, reason: revoked.append((username, reason)),
    )

    result = root_admin_logic.update_root_admin_user_password(connection, 42, "new-password")

    update_call = next(call for call in connection.statements if 'UPDATE "SkwshOrgUsers"' in call[0])
    assert update_call[1]["password_hash"] == "hash:new-password"
    assert update_call[1]["username"] == "player@example.com"
    assert revoked == [("player@example.com", "password_reset_by_root_admin")]
    assert connection.commit_count == 1
    assert result == {"updated": True, "username": "player@example.com"}


def test_root_admin_password_change_rejects_short_password():
    with pytest.raises(ValueError, match="at least 8 characters"):
        root_admin_logic.update_root_admin_user_password(RecordingConnection(), 42, "short")
