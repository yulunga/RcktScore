from datetime import datetime, timezone

from common.organization_logic import delete_personal_account, purge_due_personal_accounts


class RecordingCursor:
    def __init__(self, connection):
        self.connection = connection
        self.last_statement = ""
        self.rowcount = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, statement, parameters=None):
        self.last_statement = " ".join(statement.split())
        self.connection.statements.append((self.last_statement, parameters or {}))
        self.rowcount = 3 if self.last_statement.startswith("DELETE FROM matches") else 1

    def fetchone(self):
        if 'FROM "SkwshOrgSettings"' in self.last_statement and "FOR UPDATE" in self.last_statement:
            row = self.connection.organization_row
            self.connection.organization_row = None
            return row
        return None

    def fetchall(self):
        if "FOR UPDATE SKIP LOCKED" in self.last_statement:
            return list(self.connection.due_accounts)
        return []


class RecordingConnection:
    def __init__(self, organization_row=None, due_accounts=None):
        self.statements = []
        self.commits = 0
        self.organization_row = organization_row
        self.due_accounts = due_accounts or []

    def cursor(self):
        return RecordingCursor(self)

    def commit(self):
        self.commits += 1


def test_personal_account_deletion_marks_pending_and_revokes_sessions_without_erasing_data():
    connection = RecordingConnection({
        "id": 50001,
        "interest_request_id": 71,
        "deletion_requested_at": None,
        "deletion_purge_after": None,
    })

    result = delete_personal_account(connection, 50001, "player@example.com")

    statements = [statement for statement, _ in connection.statements]
    assert any('UPDATE "SkwshOrgSettings" SET deletion_requested_at' in statement for statement in statements)
    assert any("UPDATE org_user_sessions SET revoked_at" in statement for statement in statements)
    assert not any(statement.startswith("DELETE FROM matches") for statement in statements)
    assert not any('DELETE FROM "SkwshOrgUsers"' in statement for statement in statements)
    assert result["delete_pending"] is True
    assert result["purge_after"] > result["requested_at"]
    assert connection.commits == 1


def test_personal_account_deletion_rejects_non_owner_or_club_account():
    connection = RecordingConnection()

    try:
        delete_personal_account(connection, 50001, "member@example.com")
    except ValueError as error:
        assert "owner of a personal account" in str(error)
    else:
        raise AssertionError("Expected non-owner deletion to be rejected")

    assert connection.commits == 0
    assert not any("DELETE FROM" in statement for statement, _ in connection.statements)


def test_due_account_clearing_deletes_only_personal_tenant_matches_then_identity():
    connection = RecordingConnection(due_accounts=[{
        "id": 50001,
        "owner_username": "player@example.com",
        "interest_request_id": 71,
    }])

    result = purge_due_personal_accounts(
        connection,
        now=datetime(2027, 11, 8, tzinfo=timezone.utc),
    )

    statements = [statement for statement, _ in connection.statements]
    match_delete = next(statement for statement in statements if statement.startswith("DELETE FROM matches"))
    assert "tenant_id = %(organization_id)s" in match_delete
    assert "referee_name" not in match_delete
    assert any('DELETE FROM "SkwshOrgUsers" WHERE LOWER(clubusername)' in statement for statement in statements)
    assert any('DELETE FROM "SkwshOrgSettings"' in statement for statement in statements)
    assert any("DELETE FROM org_user_sessions" in statement for statement in statements)
    assert result == {"purged_account_count": 1, "deleted_personal_match_count": 3}
    assert connection.commits == 1


def test_clearing_job_is_a_noop_before_any_account_is_due():
    connection = RecordingConnection()

    result = purge_due_personal_accounts(connection)

    assert result == {"purged_account_count": 0, "deleted_personal_match_count": 0}
    assert not any(statement.startswith("DELETE FROM") for statement, _ in connection.statements)
    assert connection.commits == 1
