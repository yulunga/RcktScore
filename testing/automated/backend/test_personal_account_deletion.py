from common.organization_logic import delete_personal_account


class RecordingCursor:
    def __init__(self, statements, organization_row):
        self.statements = statements
        self.organization_row = organization_row

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, statement, parameters=None):
        self.statements.append((" ".join(statement.split()), parameters or {}))

    def fetchone(self):
        row = self.organization_row
        self.organization_row = None
        return row


class RecordingConnection:
    def __init__(self, organization_row=None):
        self.statements = []
        self.commits = 0
        self.organization_row = organization_row

    def cursor(self):
        return RecordingCursor(self.statements, self.organization_row)

    def commit(self):
        self.commits += 1


def test_personal_account_deletion_removes_tenant_data_and_sessions():
    connection = RecordingConnection({"id": 50001, "interest_request_id": 71})

    assert delete_personal_account(connection, 50001, "player@example.com") is True

    statements = [statement for statement, _ in connection.statements]
    assert any("DELETE FROM matches" in statement for statement in statements)
    assert any('DELETE FROM "SkwshCourts"' in statement for statement in statements)
    assert any('DELETE FROM "SkwshOrgUsers"' in statement for statement in statements)
    assert any('DELETE FROM "SkwshOrgSettings"' in statement for statement in statements)
    assert any('DELETE FROM "HitnScoreInterestRequests"' in statement for statement in statements)
    assert any("DELETE FROM org_user_sessions" in statement for statement in statements)
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
