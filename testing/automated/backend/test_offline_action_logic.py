from uuid import uuid4

import pytest

from common.offline_action_logic import claim_match_action, normalize_client_action_id


class ScriptedCursor:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, statement, parameters=None):
        self.connection.statements.append((statement, parameters or {}))

    def fetchone(self):
        return self.connection.rows.pop(0)


class ScriptedConnection:
    def __init__(self, rows):
        self.rows = list(rows)
        self.statements = []

    def cursor(self):
        return ScriptedCursor(self)


def test_claim_match_action_accepts_a_new_uuid():
    action_id = str(uuid4())
    connection = ScriptedConnection([{"client_action_id": action_id}])

    assert claim_match_action(connection, str(uuid4()), "score_point", action_id) is True
    assert len(connection.statements) == 1


def test_claim_match_action_treats_an_identical_replay_as_duplicate():
    action_id = str(uuid4())
    match_id = str(uuid4())
    connection = ScriptedConnection(
        [
            None,
            {"match_id": match_id, "action_type": "score_point"},
        ]
    )

    assert claim_match_action(connection, match_id, "score_point", action_id) is False


def test_claim_match_action_rejects_reuse_for_a_different_action():
    action_id = str(uuid4())
    match_id = str(uuid4())
    connection = ScriptedConnection(
        [
            None,
            {"match_id": match_id, "action_type": "event_action"},
        ]
    )

    with pytest.raises(ValueError, match="different match action"):
        claim_match_action(connection, match_id, "score_point", action_id)


def test_client_action_id_must_be_a_uuid():
    with pytest.raises(ValueError, match="valid UUID"):
        normalize_client_action_id("not-a-uuid")
