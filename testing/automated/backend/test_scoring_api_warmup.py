import json
from contextlib import contextmanager

import pytest

from functions.event_action import handler as event_action_handler
from functions.score_point import handler as score_point_handler
from functions.undo_action import handler as undo_action_handler


class WarmConnection:
    pass


@contextmanager
def warm_connection():
    yield WarmConnection()


@pytest.mark.parametrize(
    "handler",
    [score_point_handler, event_action_handler, undo_action_handler],
)
def test_authenticated_warmup_opens_database_path_without_recording_action(monkeypatch, handler):
    authorized = []

    def authorize(connection, event, match_id, required_capability):
        assert isinstance(connection, WarmConnection)
        assert match_id == "match-1"
        authorized.append(required_capability)
        return {"session": {"login_source": "mobile_app"}}

    def unexpected_claim(*args, **kwargs):
        raise AssertionError("Warm-up must not claim or record a match action")

    monkeypatch.setattr(handler, "get_db_connection", warm_connection)
    monkeypatch.setattr(handler, "authorize_match_session", authorize)
    monkeypatch.setattr(handler, "claim_match_action", unexpected_claim)

    response = handler.lambda_handler(
        {"body": json.dumps({"match_id": "match-1", "warm": True})},
        None,
    )
    body = json.loads(response["body"])

    assert response["statusCode"] == 200
    assert body["data"] == {"warmed": True}
    assert len(authorized) == 1


def test_score_point_still_requires_scorer_when_not_warming():
    response = score_point_handler.lambda_handler(
        {"body": json.dumps({"match_id": "match-1"})},
        None,
    )
    body = json.loads(response["body"])

    assert response["statusCode"] == 400
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert body["error"]["details"] == {"fields": ["scorer"]}


def test_event_action_still_requires_action_type_when_not_warming():
    response = event_action_handler.lambda_handler(
        {"body": json.dumps({"match_id": "match-1"})},
        None,
    )
    body = json.loads(response["body"])

    assert response["statusCode"] == 400
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert body["error"]["details"] == {"fields": ["action_type"]}
