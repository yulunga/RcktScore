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
        "create_self_service_personal_account",
        lambda current_connection, request_id, **kwargs: calls.append(
            (request_id, kwargs)
        ) or {"organization_id": 50027},
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
    assert calls[0][0] == 27
    assert calls[0][1]["source_email"] == "sender@example.com"


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
        "create_self_service_personal_account",
        lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("Club enquiry created a personal account")),
    )
    monkeypatch.setattr(handler, "_send_interest_emails", lambda **kwargs: email_calls.append(kwargs))

    response = handler.lambda_handler(registration_event("club"), None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 202
    assert body["data"]["account_created"] is False
    assert connection.commit_count == 1
    assert len(email_calls) == 1


def test_logged_in_club_subscription_enquiry_captures_full_club_details(monkeypatch):
    connection = FakeConnection()
    stored_payloads = []
    email_calls = []

    @contextmanager
    def fake_connection():
        yield connection

    event = registration_event("club")
    event["headers"]["authorization"] = "Bearer valid-session"
    event["body"].update(
        {
            "email": "client-supplied@example.com",
            "requested_plan": "club_pro",
            "club_address": "1 Centre Court",
            "club_postcode": "SW19 5AE",
            "club_email": "club@example.com",
            "club_website": "https://club.example.com",
            "club_telephone": "020 1234 5678",
        }
    )

    monkeypatch.setattr(handler, "get_db_connection", fake_connection)
    monkeypatch.setattr(
        handler,
        "require_org_user_session",
        lambda current_connection, current_event: {"username": "signed-in@example.com"},
    )
    monkeypatch.setattr(
        handler,
        "_upsert_interest_request",
        lambda current_connection, payload: stored_payloads.append(payload.copy()) or {"id": 29},
    )
    monkeypatch.setattr(handler, "_send_interest_emails", lambda **kwargs: email_calls.append(kwargs))

    response = handler.lambda_handler(event, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 202
    assert body["data"]["account_created"] is False
    assert stored_payloads[0]["email"] == "signed-in@example.com"
    assert stored_payloads[0]["requested_plan"] == "club_pro"
    assert stored_payloads[0]["club_address"] == "1 Centre Court"
    assert stored_payloads[0]["club_email"] == "club@example.com"
    assert email_calls[0]["payload"]["club_website"] == "https://club.example.com"


def test_club_subscription_enquiry_requires_complete_club_details():
    event = registration_event("club")
    event["body"]["requested_plan"] = "club_essentials"

    response = handler.lambda_handler(event, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 400
    assert body["error"]["code"] == "CLUB_DETAILS_REQUIRED"


def test_club_subscription_enquiry_requires_a_logged_in_session(monkeypatch):
    connection = FakeConnection()

    @contextmanager
    def fake_connection():
        yield connection

    event = registration_event("club")
    event["body"].update(
        {
            "requested_plan": "club_essentials",
            "club_address": "1 Centre Court",
            "club_postcode": "SW19 5AE",
            "club_email": "club@example.com",
            "club_website": "https://club.example.com",
            "club_telephone": "020 1234 5678",
        }
    )
    monkeypatch.setattr(handler, "get_db_connection", fake_connection)

    response = handler.lambda_handler(event, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 401
    assert body["error"]["code"] == "SESSION_REQUIRED"
