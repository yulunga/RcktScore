import json

from botocore.exceptions import ClientError

from functions.send_feedback import handler


def feedback_event():
    return {
        "body": {
            "name": "Test Player",
            "email": "player@example.com",
            "category": "General Feedback",
            "message": "This is a feedback test.",
            "version": "RcktScore iOS",
            "build": "test",
        },
        "headers": {"user-agent": "test-suite"},
    }


def test_feedback_sends_email_and_returns_accepted(monkeypatch):
    email_calls = []
    monkeypatch.setenv("FEEDBACK_TO_EMAIL", "hello@hitnscore.com")
    monkeypatch.setenv("FEEDBACK_FROM_EMAIL", "hello@hitnscore.com")
    monkeypatch.setattr(handler, "send_email_message", lambda **kwargs: email_calls.append(kwargs))

    response = handler.lambda_handler(feedback_event(), None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 202
    assert body["data"]["accepted"] is True
    assert email_calls[0]["destination_email"] == "hello@hitnscore.com"
    assert email_calls[0]["reply_to_addresses"] == ["player@example.com"]


def test_feedback_maps_ses_rejection_to_api_error(monkeypatch):
    monkeypatch.setattr(
        handler,
        "send_email_message",
        lambda **kwargs: (_ for _ in ()).throw(
            ClientError(
                {"Error": {"Code": "MessageRejected", "Message": "Identity is not verified"}},
                "SendEmail",
            )
        ),
    )

    response = handler.lambda_handler(feedback_event(), None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 503
    assert body["error"]["code"] == "FEEDBACK_DELIVERY_FAILED"
