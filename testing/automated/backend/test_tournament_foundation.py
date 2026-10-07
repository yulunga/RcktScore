import pytest

from common.tournament import access, tournament_logic


class SingleRowCursor:
    def __init__(self, connection):
        self.connection = connection
        self.rowcount = 1

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, query, params=None):
        self.connection.statements.append((" ".join(query.split()), params or {}))

    def fetchone(self):
        return self.connection.rows.pop(0) if self.connection.rows else None


class SingleRowConnection:
    def __init__(self, rows):
        self.rows = list(rows)
        self.statements = []
        self.committed = False

    def cursor(self):
        return SingleRowCursor(self)

    def commit(self):
        self.committed = True


def test_missing_tournament_feature_row_defaults_to_disabled():
    connection = SingleRowConnection([{
        "organization_id": 12,
        "organization_type": "club",
        "web_enabled": False,
        "enabled_by": None,
        "enabled_at": None,
        "updated_at": None,
    }])

    feature = access.get_tournament_feature(connection, 12)

    assert feature["web_enabled"] is False
    with pytest.raises(access.TournamentAccessError):
        access.require_tournament_feature(SingleRowConnection([{
            "organization_id": 12,
            "organization_type": "club",
            "web_enabled": False,
            "enabled_by": None,
            "enabled_at": None,
            "updated_at": None,
        }]), 12)


def test_personal_accounts_cannot_use_tournament_manager():
    connection = SingleRowConnection([{
        "organization_id": 50001,
        "organization_type": "personal",
        "web_enabled": True,
        "enabled_by": "root",
        "enabled_at": None,
        "updated_at": None,
    }])

    with pytest.raises(access.TournamentAccessError):
        access.require_tournament_feature(connection, 50001)


def test_root_admin_feature_update_is_committed(monkeypatch):
    connection = SingleRowConnection([])
    returned_features = iter([
        {"organization_id": 7, "organization_type": "club", "web_enabled": False},
        {"organization_id": 7, "organization_type": "club", "web_enabled": True},
    ])
    monkeypatch.setattr(access, "get_tournament_feature", lambda *_args: next(returned_features))

    feature = access.set_tournament_feature(connection, 7, True, "root@example.com")

    assert feature["web_enabled"] is True
    assert connection.committed is True
    assert any("INSERT INTO tournament_organization_features" in query for query, _ in connection.statements)


@pytest.mark.parametrize("sport", ["badminton", "pickleball", ""])
def test_tournament_creation_rejects_unsupported_sports_before_database_write(sport):
    with pytest.raises(ValueError):
        tournament_logic.create_tournament(
            None,
            1,
            {"name": "Club Open", "sport": sport, "draw_format": "knockout"},
            "admin@example.com",
        )


def test_tournament_creation_rejects_end_before_start():
    with pytest.raises(ValueError, match="ends_on cannot be before starts_on"):
        tournament_logic.create_tournament(
            None,
            1,
            {
                "name": "Club Open",
                "sport": "squash",
                "draw_format": "round_robin",
                "starts_on": "2026-10-10",
                "ends_on": "2026-10-09",
            },
            "admin@example.com",
        )


def test_player_normalization_is_case_and_whitespace_insensitive():
    assert tournament_logic._normalize_name("  Alex ", " Mc Kay  ") == "alex mc kay"
