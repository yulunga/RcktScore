import secrets
from datetime import datetime, timedelta, timezone

from werkzeug.security import generate_password_hash

from common.mailer import send_email_message
from common.notification_templates import render_notification_template
from common.organization_logic import APP_DISPLAY_NAME, is_valid_email_address, normalize_email_address


RESET_TOKEN_TTL_HOURS = 2


def _utcnow():
    return datetime.now(timezone.utc)


def _build_reset_url(base_url, token):
    if not base_url:
        raise ValueError("Password reset base URL must be configured")

    return f"{base_url.rstrip('/')}/help?mode=reset&token={token}"


def _send_password_reset_email(*, username, reset_url, source_email):
    context = {
        "app_name": APP_DISPLAY_NAME,
        "reset_url": reset_url,
        "username": username,
        "expires_hours": RESET_TOKEN_TTL_HOURS,
    }
    subject = render_notification_template("password_reset_subject.txt", context).strip()
    body_text = render_notification_template("password_reset_body.txt", context).strip()

    send_email_message(
        destination_email=username,
        source_email=source_email,
        subject=subject,
        text_body=body_text,
    )


def request_password_reset(connection, email, *, source_email, reset_base_url):
    username = normalize_email_address(email)
    if not is_valid_email_address(username):
        raise ValueError("A valid email address is required")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM "SkwshOrgUsers"
            WHERE LOWER(clubusername) = LOWER(%(username)s)
            LIMIT 1
            """,
            {"username": username},
        )
        user_row = cursor.fetchone()

        if not user_row:
            return {"accepted": True, "email_sent": False}

        reset_token = secrets.token_urlsafe(32)
        requested_at = _utcnow()
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET password_reset_token = %(reset_token)s,
                password_reset_requested_at = %(requested_at)s
            WHERE LOWER(clubusername) = LOWER(%(username)s)
            """,
            {
                "reset_token": reset_token,
                "requested_at": requested_at,
                "username": username,
            },
        )

    reset_url = _build_reset_url(reset_base_url, reset_token)
    _send_password_reset_email(
        username=username,
        reset_url=reset_url,
        source_email=source_email,
    )
    connection.commit()
    return {"accepted": True, "email_sent": True}


def confirm_password_reset(connection, token, password):
    reset_token = (token or "").strip()
    if not reset_token:
        raise ValueError("Reset token is required")

    if not password or len(password) < 8:
        raise ValueError("Password must be at least 8 characters")

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT clubusername, password_reset_requested_at
            FROM "SkwshOrgUsers"
            WHERE password_reset_token = %(reset_token)s
            ORDER BY password_reset_requested_at DESC NULLS LAST
            LIMIT 1
            """,
            {"reset_token": reset_token},
        )
        user_row = cursor.fetchone()

        if not user_row:
            raise ValueError("Reset link is invalid or has already been used")

        requested_at = user_row.get("password_reset_requested_at")
        if not requested_at or requested_at < _utcnow() - timedelta(hours=RESET_TOKEN_TTL_HOURS):
            raise ValueError("Reset link has expired")

        username = normalize_email_address(user_row["clubusername"])
        password_hash = generate_password_hash(password)
        validated_at = _utcnow()
        cursor.execute(
            """
            UPDATE "SkwshOrgUsers"
            SET password_hash = %(password_hash)s,
                password_reset_token = NULL,
                password_reset_requested_at = NULL,
                approval_status = CASE
                    WHEN approval_status = 'pending' THEN 'approved'
                    ELSE approval_status
                END,
                approved_at = CASE
                    WHEN approval_status = 'pending' THEN %(validated_at)s
                    ELSE approved_at
                END
            WHERE LOWER(clubusername) = LOWER(%(username)s)
              AND password_reset_token = %(reset_token)s
            """,
            {
                "password_hash": password_hash,
                "username": username,
                "reset_token": reset_token,
                "validated_at": validated_at,
            },
        )
        cursor.execute(
            """
            UPDATE "HitnScoreInterestRequests"
            SET email_validated = true,
                email_validated_at = COALESCE(email_validated_at, %(validated_at)s),
                updated_at = %(validated_at)s
            WHERE LOWER(email) = LOWER(%(username)s)
            """,
            {
                "username": username,
                "validated_at": validated_at,
            },
        )

    connection.commit()
    return {"reset": True}
