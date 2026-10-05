import pytest

from common import padel_match_logic as padel


def test_padel_create_enforces_doubles_and_standard_defaults(monkeypatch):
    captured = {}

    def fake_create(connection, payload, source="api"):
        captured.update(payload)
        captured["source"] = source
        return {"sport": payload["sport"]}

    monkeypatch.setattr(padel.shared, "create_match", fake_create)

    result = padel.create_match(
        object(),
        {
            "tenant_id": "50001",
            "player1_name": "Alex / Casey",
            "player2_name": "Blair / Drew",
            "team1_player2_name": "Casey",
            "team2_player2_name": "Drew",
        },
        source="test",
    )

    assert result == {"sport": "padel"}
    assert captured["sport"] == "padel"
    assert captured["team_format"] == "doubles"
    assert captured["score_type"] == 6
    assert captured["best_of"] == 3
    assert captured["source"] == "test"


@pytest.mark.parametrize("missing_field", ["team1_player2_name", "team2_player2_name"])
def test_padel_create_requires_a_partner_on_each_team(missing_field):
    payload = {
        "tenant_id": "50001",
        "player1_name": "Alex / Casey",
        "player2_name": "Blair / Drew",
        "team1_player2_name": "Casey",
        "team2_player2_name": "Drew",
    }
    payload[missing_field] = ""

    with pytest.raises(ValueError, match="two named players on each team"):
        padel.create_match(object(), payload)


def test_padel_operations_delegate_to_shared_court_scoring_engine(monkeypatch):
    monkeypatch.setattr(padel.shared, "score_point", lambda *args, **kwargs: "score")
    monkeypatch.setattr(padel.shared, "event_action", lambda *args, **kwargs: "event")
    monkeypatch.setattr(padel.shared, "undo_last_action", lambda *args, **kwargs: "undo")
    monkeypatch.setattr(padel.shared, "activate_scheduled_match", lambda *args, **kwargs: "activate")
    monkeypatch.setattr(padel.shared, "serialize_match", lambda *args, **kwargs: "serialize")
    monkeypatch.setattr(padel.shared, "end_match", lambda *args, **kwargs: "end")

    connection = object()
    assert padel.score_point(connection, "match", "player1") == "score"
    assert padel.event_action(connection, "match", "server", {}) == "event"
    assert padel.undo_last_action(connection, "match") == "undo"
    assert padel.activate_scheduled_match(connection, "match") == "activate"
    assert padel.serialize_match({}, []) == "serialize"
    assert padel.end_match(connection, "match") == "end"
