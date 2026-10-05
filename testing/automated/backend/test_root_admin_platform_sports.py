from common import root_admin_logic


class RecordingCursor:
    def __init__(self, membership=None):
        self.membership = membership
        self.executions = []
        self.rowcount = 1

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, query, params=None):
        self.executions.append((" ".join(query.split()), params or {}))

    def fetchone(self):
        return self.membership


class RecordingConnection:
    def __init__(self, membership=None):
        self.recording_cursor = RecordingCursor(membership)
        self.committed = False

    def cursor(self):
        return self.recording_cursor

    def commit(self):
        self.committed = True


def test_platform_availability_save_does_not_change_organizations_or_users(monkeypatch):
    connection = RecordingConnection()
    monkeypatch.setattr(
        root_admin_logic,
        "get_root_admin_platform_sports",
        lambda _connection: {"enabled_sports": ["squash", "padel"]},
    )

    result = root_admin_logic.update_root_admin_platform_sports(
        connection,
        enabled_sports_web=["squash"],
        enabled_sports_ios=["squash", "padel"],
    )

    statements = [query for query, _params in connection.recording_cursor.executions]
    assert any("INSERT INTO platform_settings" in query for query in statements)
    assert not any('UPDATE "SkwshOrgSettings"' in query for query in statements)
    assert not any('UPDATE "SkwshOrgUsers"' in query for query in statements)
    assert not any("UPDATE org_user_sessions" in query for query in statements)
    assert result["applied_to_all"] is False
    assert result["affected_organization_count"] == 0
    assert result["affected_membership_count"] == 0
    assert connection.committed is True


def test_explicit_bulk_apply_still_updates_every_membership(monkeypatch):
    connection = RecordingConnection()
    monkeypatch.setattr(root_admin_logic, "get_root_admin_platform_sports", lambda _connection: {})

    result = root_admin_logic.update_root_admin_platform_sports(
        connection,
        enabled_sports_web=["squash"],
        enabled_sports_ios=["squash", "padel"],
        apply_to_all=True,
    )

    statements = [query for query, _params in connection.recording_cursor.executions]
    assert any('UPDATE "SkwshOrgSettings"' in query for query in statements)
    assert any('UPDATE "SkwshOrgUsers"' in query for query in statements)
    assert any("UPDATE org_user_sessions" in query for query in statements)
    assert result["applied_to_all"] is True


def test_personal_user_assignment_updates_only_its_organization_gate(monkeypatch):
    connection = RecordingConnection(
        {
            "id": 12,
            "clubusername": "test@example.com",
            "organization_id": 34,
            "org_type": "personal",
        }
    )
    monkeypatch.setattr(root_admin_logic, "_root_admin_user_username", lambda *_args: "test@example.com")
    monkeypatch.setattr(root_admin_logic, "constrain_enabled_sports", lambda _connection, values: values)
    monkeypatch.setattr(
        root_admin_logic,
        "constrain_user_enabled_sports",
        lambda _connection, _organization_id, values, _client_type: values,
    )

    result = root_admin_logic.update_root_admin_user_sport_access(
        connection,
        "user-1",
        12,
        enabled_sports_web=["squash"],
        enabled_sports_ios=["squash", "padel"],
    )

    organization_updates = [
        params
        for query, params in connection.recording_cursor.executions
        if 'UPDATE "SkwshOrgSettings"' in query
    ]
    assert len(organization_updates) == 1
    assert organization_updates[0]["organization_id"] == 34
    assert result["enabled_sports_ios"] == ["squash", "padel"]
    assert result["organization_sports_updated"] is True
