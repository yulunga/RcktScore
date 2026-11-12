import hashlib
import os
import re

from aws_lambda_powertools import Logger
from botocore.exceptions import BotoCoreError, ClientError

from common.mailer import send_email_message
from common.notification_templates import render_branded_email
from common.public_registration import create_challenge, get_registration_settings, verify_challenge
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


logger = Logger(service="public_registration")
EMAIL_PATTERN = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


def _update_settings(connection, event, payload):
    require_root_admin_session(connection, event)
    enabled = payload.get("enabled")
    message = payload.get("message")
    if not isinstance(enabled, bool) or not isinstance(message, str) or not 1 <= len(message.strip()) <= 1000:
        return error_response(400, "INVALID_SETTINGS", "Enter a message between 1 and 1,000 characters.")
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE public_registration_settings
            SET public_registration_enabled = %s, public_registration_message = %s
            WHERE id = 'default'
            RETURNING public_registration_enabled AS enabled, public_registration_message AS message
            """,
            (enabled, message.strip()),
        )
        settings = cursor.fetchone()
    connection.commit()
    return success_response(200, settings)


def _register_interest(connection, payload):
    settings = get_registration_settings(connection, lock=True)
    if settings["enabled"]:
        return error_response(409, "REGISTRATION_OPEN", "Registration is open. Use Want In to sign up.")

    def field(name):
        value = payload.get(name)
        return value.strip() if isinstance(value, str) else ""

    if field("company"):
        return success_response(202, {"accepted": True})

    first_name, surname, email, use_type = (field(name) for name in ("first_name", "surname", "email", "use_type"))
    email = email.lower()
    if not (
        1 <= len(first_name) <= 100 and 1 <= len(surname) <= 100
        and len(email) <= 254 and EMAIL_PATTERN.fullmatch(email)
        and use_type in {"personal", "club"}
    ):
        return error_response(400, "INVALID_INTEREST_DETAILS", "Enter your name, a valid email address and how you plan to use HitnScore.")
    token, answer = field("challenge_token"), field("challenge_answer")
    if len(token) > 150 or len(answer) > 2 or not verify_challenge(settings["challenge_key"], token, answer):
        return error_response(400, "INVALID_HUMAN_CHECK", "The answer is incorrect or the question has expired. Try the new question.")

    with connection.cursor() as cursor:
        cursor.execute("DELETE FROM public_registration_challenges WHERE expires_at < now()")
        cursor.execute(
            """
            INSERT INTO public_registration_challenges (token_hash, expires_at)
            VALUES (%s, to_timestamp(%s))
            ON CONFLICT DO NOTHING
            RETURNING token_hash
            """,
            (hashlib.sha256(token.encode()).hexdigest(), int(token.split(".", 1)[0])),
        )
        if not cursor.fetchone():
            return error_response(400, "INVALID_HUMAN_CHECK", "This question has already been answered. Try the new question.")
        cursor.execute(
            """
            INSERT INTO public_registration_interest (email, use_type, first_name, surname)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (email, use_type) DO NOTHING
            RETURNING email
            """,
            (email, use_type, first_name, surname),
        )
        new_interest = cursor.fetchone()
    if new_interest:
        details = [
            ("First name", first_name),
            ("Surname", surname),
            ("Email", email),
            ("Use", use_type.title()),
        ]
        send_email_message(
            source_email=os.getenv("INTEREST_FROM_EMAIL", "hello@hitnscore.com"),
            destination_email=os.getenv("INTEREST_TO_EMAIL", "hello@hitnscore.com"),
            reply_to_addresses=[email],
            subject="New HitnScore registration interest",
            text_body="\n".join(f"{label}: {value}" for label, value in details),
            html_body=render_branded_email(title="New registration interest", detail_rows=details),
        )
    connection.commit()
    return success_response(202, {"accepted": True})


def lambda_handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method != "GET":
        try:
            payload = parse_body(event)
        except ValueError:
            payload = None
        if not isinstance(payload, dict):
            return error_response(400, "INVALID_REQUEST", "Enter valid request details.")

    try:
        with get_db_connection() as connection:
            if method == "PUT":
                return _update_settings(connection, event, payload)
            if method == "POST":
                return _register_interest(connection, payload)

            settings = get_registration_settings(connection)
            key = settings.pop("challenge_key")
            if not settings["enabled"] and (event.get("queryStringParameters") or {}).get("challenge") == "1":
                settings["challenge"] = create_challenge(key)
            return success_response(200, settings)
    except SessionAuthError as error:
        return session_error_response(error)
    except (BotoCoreError, ClientError):
        logger.exception("Registration interest email failed")
        return error_response(503, "INTEREST_EMAIL_FAILED", "Unable to send your interest right now. Please try again.")
