import json
from contextlib import contextmanager

from functions.register_interest import handler


class FakeConnection:
    def __init__(self):
        self.commit_count = 0

    def commit(self):
        self.commit_count += 1


def registration_event(use_type):
    return {
        "body": {
            "first_name": "Test",
            "surname": "Player",
            "email": "player@example.com",
            "use_type": use_type,
            "club_name": "Example Club" if use_type == "club" else "",
        },
        "headers": {"user-agent": "test-suite"},
    }


def test_personal_registration_creates_account_without_manual_approval(monkeypatch):
    connection = FakeConnection()
    calls = []

    @contextmanager
    def fake_connection():
        yield connection

    monkeypatch.setenv("PASSWORD_RESET_BASE_URL", "https://example.com")
    monkeypatch.setenv("INTEREST_FROM_EMAIL", "sender@example.com")
    monkeypatch.setattr(handler, "get_db_connection", fake_connection)
    monkeypatch.setattr(handler, "_upsert_interest_request", lambda current_connection, payload: {"id": 27})
    monkeypatch.setattr(
        handler,
        "update_root_admin_interest_request_status",
        lambda current_connection, request_id, status, **kwargs: calls.append(
            (request_id, status, kwargs)
        ) or {"personal_account": {"organization_id": 50027}},
    )
    monkeypatch.setattr(
        handler,
        "_send_interest_emails",
        lambda **kwargs: (_ for _ in ()).throw(AssertionError("Personal signup sent club enquiry emails")),
    )

    response = handler.lambda_handler(registration_event("personal"), None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 201
    assert body["data"]["account_created"] is True
    assert body["data"]["requires_password_setup"] is True
    assert calls[0][0:2] == (27, "approved")
    assert calls[0][2]["updated_by"] == "self-service signup"


def test_club_registration_remains_a_managed_enquiry(monkeypatch):
    connection = FakeConnection()
    email_calls = []

    @contextmanager
    def fake_connection():
        yield connection

    monkeypatch.setattr(handler, "get_db_connection", fake_connection)
    monkeypatch.setattr(handler, "_upsert_interest_request", lambda current_connection, payload: {"id": 28})
    monkeypatch.setattr(
        handler,
        "update_root_admin_interest_request_status",
        lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("Club enquiry created a personal account")),
    )
    monkeypatch.setattr(handler, "_send_interest_emails", lambda **kwargs: email_calls.append(kwargs))

    response = handler.lambda_handler(registration_event("club"), None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 202
    assert body["data"]["account_created"] is False
    assert connection.commit_count == 1
    assert len(email_calls) == 1
