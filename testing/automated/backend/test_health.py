import json
from contextlib import contextmanager

import pytest

from functions.health import handler


class ReadyCursor:
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, query):
        assert query == "SELECT 1 AS ready"

    def fetchone(self):
        return {"ready": 1}


class ReadyConnection:
    def cursor(self):
        return ReadyCursor()


@contextmanager
def ready_connection():
    yield ReadyConnection()


@contextmanager
def failed_connection():
    raise RuntimeError("database unavailable")
    yield


def test_http_health_returns_database_readiness(monkeypatch):
    monkeypatch.setattr(handler, "get_db_connection", ready_connection)

    response = handler.lambda_handler({}, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 200
    assert body["data"]["status"] == "healthy"
    assert body["data"]["checks"] == {"database": "healthy"}


def test_http_health_hides_database_failure_details(monkeypatch):
    monkeypatch.setattr(handler, "get_db_connection", failed_connection)

    response = handler.lambda_handler({}, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 503
    assert body["error"]["code"] == "SERVICE_UNAVAILABLE"
    assert "database unavailable" not in response["body"]


def test_scheduled_health_raises_for_cloudwatch_alarm(monkeypatch):
    monkeypatch.setattr(handler, "get_db_connection", failed_connection)

    with pytest.raises(RuntimeError, match="Scheduled production health check failed"):
        handler.lambda_handler({"source": handler.SCHEDULE_SOURCE}, None)
