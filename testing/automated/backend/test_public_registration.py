import re
from unittest.mock import MagicMock

from common.public_registration import create_challenge, verify_challenge
from functions.public_registration import handler


def test_registration_interest_requires_a_valid_math_answer_and_emails_details(monkeypatch):
    connection = MagicMock()
    cursor = connection.cursor.return_value.__enter__.return_value
    cursor.fetchone.side_effect = [{"token_hash": "used"}, {"email": "player@example.com"}]
    send_email = MagicMock()
    monkeypatch.setattr(handler, "get_registration_settings", lambda _conn, **_kwargs: {
        "enabled": False, "challenge_key": "test-key",
    })
    monkeypatch.setattr(handler, "send_email_message", send_email)
    monkeypatch.setenv("INTEREST_TO_EMAIL", "hello@hitnscore.com")

    challenge = create_challenge("test-key")
    operands = re.findall(r"\d+", challenge["prompt"])
    answer = str(sum(map(int, operands)))
    payload = {
        "first_name": "Test", "surname": "Player", "email": "player@example.com",
        "use_type": "club", "challenge_token": challenge["token"], "challenge_answer": "0",
    }

    assert handler._register_interest(connection, payload)["statusCode"] == 400
    connection.cursor.assert_not_called()
    send_email.assert_not_called()

    payload["challenge_answer"] = answer
    assert handler._register_interest(connection, payload)["statusCode"] == 202
    assert any("INSERT INTO public_registration_interest" in call.args[0] for call in cursor.execute.call_args_list)
    assert send_email.call_args.kwargs["destination_email"] == "hello@hitnscore.com"
    assert "Use: Club" in send_email.call_args.kwargs["text_body"]
    connection.commit.assert_called_once()


def test_expired_challenge_is_rejected(monkeypatch):
    monkeypatch.setattr("common.public_registration.time.time", lambda: 0)
    challenge = create_challenge("test-key")
    answer = str(sum(map(int, re.findall(r"\d+", challenge["prompt"]))))
    assert verify_challenge("test-key", challenge["token"], answer)

    monkeypatch.setattr("common.public_registration.time.time", lambda: 901)
    assert not verify_challenge("test-key", challenge["token"], answer)


def test_open_registration_requires_the_normal_signup_path(monkeypatch):
    connection = MagicMock()
    monkeypatch.setattr(handler, "get_registration_settings", lambda _conn, **_kwargs: {"enabled": True})

    assert handler._register_interest(connection, {})["statusCode"] == 409
    connection.cursor.assert_not_called()
