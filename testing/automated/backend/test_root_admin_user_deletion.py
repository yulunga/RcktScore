from common.root_admin_logic import delete_root_admin_user_account


class RecordingCursor:
    def __init__(self, connection):
        self.connection = connection
        self.last_statement = ""
        self.rowcount = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params=None):
        self.last_statement = " ".join(statement.split())
        self.connection.statements.append((self.last_statement, params or {}))
        self.rowcount = 2 if self.last_statement.startswith("DELETE FROM matches") else 1

    def fetchone(self):
        if "SELECT clubusername" in self.last_statement:
            return {"clubusername": "player@example.com"}
        return None

    def fetchall(self):
        if "FOR UPDATE OF organization" in self.last_statement:
            return [{"id": 50001, "interest_request_id": 71}]
        return []


class RecordingConnection:
    def __init__(self):
        self.statements = []
        self.commit_count = 0

    def cursor(self):
        return RecordingCursor(self)

    def commit(self):
        self.commit_count += 1


def test_root_admin_deletion_preserves_matches_by_default_and_archives_personal_tenant():
    connection = RecordingConnection()

    result = delete_root_admin_user_account(connection, 42, delete_games=False)
    statements = [statement for statement, _ in connection.statements]

    assert not any(statement.startswith("DELETE FROM matches") for statement in statements)
    assert any('UPDATE "SkwshOrgSettings" SET owner_username' in statement for statement in statements)
    assert any('DELETE FROM "SkwshOrgUsers"' in statement for statement in statements)
    assert result["games_deleted"] is False
    assert connection.commit_count == 1


def test_root_admin_deletion_removes_attributed_matches_before_personal_tenant():
    connection = RecordingConnection()

    result = delete_root_admin_user_account(connection, 42, delete_games=True)
    statements = [statement for statement, _ in connection.statements]
    match_index = next(index for index, statement in enumerate(statements) if statement.startswith("DELETE FROM matches"))
    membership_index = next(index for index, statement in enumerate(statements) if 'DELETE FROM "SkwshOrgUsers" WHERE organization_id' in statement)
    organization_index = next(index for index, statement in enumerate(statements) if 'DELETE FROM "SkwshOrgSettings"' in statement)

    assert match_index < membership_index < organization_index
    assert result["games_deleted"] is True
    assert result["deleted_match_count"] == 2
    assert connection.commit_count == 1
