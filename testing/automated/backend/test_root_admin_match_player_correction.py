from uuid import UUID

import pytest

from common import root_admin_logic


MATCH_ID = UUID("4b49455c-8834-46ce-801e-2c297c9cd68c")


class RecordingCursor:
    def __init__(self, statements):
        self.statements = statements

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params=None):
        self.statements.append((" ".join(statement.split()), params or {}))


class RecordingConnection:
    def __init__(self):
        self.statements = []
        self.commits = 0

    def cursor(self):
        return RecordingCursor(self.statements)

    def commit(self):
        self.commits += 1


def completed_match_row(**overrides):
    row = {
        "id": MATCH_ID,
        "tenant_id": 2,
        "sport": "squash",
        "status": "completed",
        "player1_name": "AdamS",
        "player1_surname": None,
        "player2_name": "SamO",
        "player2_surname": None,
        "winner_side": "player1",
        "winner_name": "AdamS",
    }
    row.update(overrides)
    return row


def test_completed_match_player_correction_updates_match_and_appends_audit_event(monkeypatch):
    connection = RecordingConnection()
    row = completed_match_row()
    monkeypatch.setattr(root_admin_logic, "_get_root_admin_match_row", lambda *args, **kwargs: row)
    monkeypatch.setattr(root_admin_logic, "_serialize_match_row", lambda *args, **kwargs: {"state": {}})
    monkeypatch.setattr(root_admin_logic, "get_root_admin_match", lambda *args, **kwargs: {"id": str(MATCH_ID)})

    result = root_admin_logic.correct_root_admin_match_players(
        connection,
        MATCH_ID,
        {
            "player1_name": "Adam",
            "player1_surname": "Smith",
            "player2_name": "Sam",
            "player2_surname": "Owens",
        },
        updated_by="ground.control",
    )

    assert result == {"id": str(MATCH_ID)}
    assert connection.commits == 1
    update_params = connection.statements[0][1]
    assert update_params["player1_name"] == "Adam"
    assert update_params["player1_surname"] == "Smith"
    assert update_params["player2_name"] == "Sam"
    assert update_params["player2_surname"] == "Owens"
    assert update_params["winner_name"] == "Adam"
    audit_params = connection.statements[1][1]
    assert audit_params["actor_username"] == "ground.control"
    assert audit_params["payload"].obj["old_names"]["player1_name"] == "AdamS"
    assert audit_params["payload"].obj["player1_name"] == "Adam"
    assert "root_admin_name_correction" in connection.statements[1][0]


def test_match_player_correction_rejects_an_active_match(monkeypatch):
    connection = RecordingConnection()
    monkeypatch.setattr(
        root_admin_logic,
        "_get_root_admin_match_row",
        lambda *args, **kwargs: completed_match_row(status="active"),
    )

    with pytest.raises(ValueError, match="only be corrected after"):
        root_admin_logic.correct_root_admin_match_players(
            connection,
            MATCH_ID,
            {"player1_name": "Adam", "player2_name": "Sam"},
            updated_by="ground.control",
        )

    assert connection.statements == []
    assert connection.commits == 0


def test_match_player_correction_preserves_and_updates_doubles_lineup(monkeypatch):
    connection = RecordingConnection()
    row = completed_match_row(sport="padel", player1_name="A One / B Two", player2_name="C Three / D Four")
    state = {
        "team_format": "doubles",
        "tennis_teams": {
            "player1": [
                {"id": "team1_player1", "first_name": "A", "surname": "One", "display_name": "A One"},
                {"id": "team1_player2", "first_name": "B", "surname": "Two", "display_name": "B Two"},
            ],
            "player2": [
                {"id": "team2_player1", "first_name": "C", "surname": "Three", "display_name": "C Three"},
                {"id": "team2_player2", "first_name": "D", "surname": "Four", "display_name": "D Four"},
            ],
        },
    }
    monkeypatch.setattr(root_admin_logic, "_get_root_admin_match_row", lambda *args, **kwargs: row)
    monkeypatch.setattr(root_admin_logic, "_serialize_match_row", lambda *args, **kwargs: {"state": state})
    monkeypatch.setattr(root_admin_logic, "get_root_admin_match", lambda *args, **kwargs: {"id": str(MATCH_ID)})

    root_admin_logic.correct_root_admin_match_players(
        connection,
        MATCH_ID,
        {"team1_player2_name": "Bea", "team1_player2_surname": "Second"},
        updated_by="ground.control",
    )

    update_params = connection.statements[0][1]
    assert update_params["player1_name"] == "A One / Bea Second"
    assert update_params["player1_surname"] is None
    teams = connection.statements[1][1]["payload"].obj["tennis_teams"]
    assert teams["player1"][1]["display_name"] == "Bea Second"
