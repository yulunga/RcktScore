import os
import re
from datetime import datetime, timezone

from aws_lambda_powertools import Logger
from botocore.exceptions import BotoCoreError, ClientError
from psycopg.errors import UndefinedTable

from common.mailer import send_email_message
from common.notification_templates import render_notification_template
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="register_interest")

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
VALID_USE_TYPES = {"personal", "club"}


def _utcnow():
    return datetime.now(timezone.utc)


def _display_use_type(value):
    return "Club use" if value == "club" else "Personal use"


def _upsert_interest_request(connection, payload):
    now = _utcnow()
    email = payload["email"]
    values = {
        "created_at": now,
        "updated_at": now,
        "first_name": payload["first_name"],
        "surname": payload["surname"],
        "email": email,
        "use_type": payload["use_type"],
        "club_name": payload.get("club_name") or None,
        "approval_status": "pending",
        "email_validated": False,
        "page_url": payload.get("page_url") or None,
        "user_agent": payload.get("user_agent") or None,
    }

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM "HitnScoreInterestRequests"
            WHERE LOWER(email) = LOWER(%(email)s)
            LIMIT 1
            """,
            {"email": email},
        )
        existing_row = cursor.fetchone()

        if existing_row:
            cursor.execute(
                """
                UPDATE "HitnScoreInterestRequests"
                SET updated_at = %(updated_at)s,
                    first_name = %(first_name)s,
                    surname = %(surname)s,
                    use_type = %(use_type)s,
                    club_name = %(club_name)s,
                    approval_status = %(approval_status)s,
                    page_url = %(page_url)s,
                    user_agent = %(user_agent)s
                WHERE id = %(id)s
                RETURNING id
                """,
                {**values, "id": existing_row["id"]},
            )
            return cursor.fetchone()

        cursor.execute(
            """
            INSERT INTO "HitnScoreInterestRequests" (
                created_at,
                updated_at,
                first_name,
                surname,
                email,
                use_type,
                club_name,
                approval_status,
                email_validated,
                page_url,
                user_agent
            )
            VALUES (
                %(created_at)s,
                %(updated_at)s,
                %(first_name)s,
                %(surname)s,
                %(email)s,
                %(use_type)s,
                %(club_name)s,
                %(approval_status)s,
                %(email_validated)s,
                %(page_url)s,
                %(user_agent)s
            )
            RETURNING id
            """,
            values,
        )
        return cursor.fetchone()


def _send_interest_emails(*, payload, destination_email, source_email):
    template_context = {
        "first_name": payload["first_name"],
        "surname": payload["surname"],
        "email": payload["email"],
        "use_type": _display_use_type(payload["use_type"]),
        "club_name": payload.get("club_name") or "Not provided",
        "page_url": payload.get("page_url") or "Unknown",
        "user_agent": payload.get("user_agent") or "Unknown",
    }

    user_subject = render_notification_template("interest_confirmation_subject.txt", template_context).strip()
    user_body = render_notification_template("interest_confirmation_body.txt", template_context).strip()
    admin_subject = render_notification_template("interest_admin_subject.txt", template_context).strip()
    admin_body = render_notification_template("interest_admin_body.txt", template_context).strip()

    send_email_message(
        source_email=source_email,
        destination_email=payload["email"],
        subject=user_subject,
        text_body=user_body,
    )
    send_email_message(
        source_email=source_email,
        destination_email=destination_email,
        reply_to_addresses=[payload["email"]],
        subject=admin_subject,
        text_body=admin_body,
    )


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["first_name", "surname", "email", "use_type"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    first_name = (payload.get("first_name") or "").strip()
    surname = (payload.get("surname") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    use_type = (payload.get("use_type") or "").strip().lower()
    club_name = (payload.get("club_name") or "").strip()
    honeypot = (payload.get("company") or "").strip()

    if not EMAIL_PATTERN.match(email):
        return error_response(400, "INVALID_EMAIL", "A valid email address is required")
    if use_type not in VALID_USE_TYPES:
        return error_response(400, "INVALID_USE_TYPE", "A valid use type is required")
    if use_type == "club" and not club_name:
        return error_response(400, "CLUB_NAME_REQUIRED", "Club name is required for club use")

    # Quietly absorb obvious bot submissions without sending an email.
    if honeypot:
        logger.warning("Interest honeypot triggered for email=%s", email)
        return success_response(202, {"accepted": True})

    destination_email = os.getenv("INTEREST_TO_EMAIL", "rcktinterest@ucingo.com")
    source_email = os.getenv("INTEREST_FROM_EMAIL", destination_email)
    page_url = (payload.get("page_url") or "").strip()
    user_agent = (
        payload.get("user_agent")
        or (event.get("headers") or {}).get("user-agent")
        or "Unknown"
    )

    request_payload = {
        "first_name": first_name,
        "surname": surname,
        "email": email,
        "use_type": use_type,
        "club_name": club_name,
        "page_url": page_url,
        "user_agent": user_agent,
    }

    try:
        with get_db_connection() as connection:
            interest_row = _upsert_interest_request(connection, request_payload)
            connection.commit()
    except UndefinedTable:
        logger.exception("Interest request table is missing")
        return error_response(
            500,
            "INTEREST_REQUESTS_TABLE_MISSING",
            "Interest request storage is not ready. Please run the interest requests database migration.",
        )
    except Exception:
        logger.exception("Interest request database write failed")
        return error_response(
            500,
            "INTEREST_REQUEST_FAILED",
            "Unable to register interest right now.",
        )

    try:
        _send_interest_emails(
            payload=request_payload,
            destination_email=destination_email,
            source_email=source_email,
        )
    except (BotoCoreError, ClientError):
        logger.exception("Interest request email failed")
        return error_response(
            500,
            "INTEREST_EMAIL_FAILED",
            "Unable to send confirmation email. Please check the email sender configuration.",
        )
    except Exception:
        logger.exception("Interest request email failed unexpectedly")
        return error_response(
            500,
            "INTEREST_EMAIL_FAILED",
            "Unable to send confirmation email. Please check the email sender configuration.",
        )

    logger.info(
        "Interest request accepted id=%s email=%s use_type=%s",
        interest_row.get("id"),
        email,
        use_type,
    )

    return success_response(202, {"accepted": True})
