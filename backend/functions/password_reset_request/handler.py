import os

from aws_lambda_powertools import Logger

from common.password_reset_logic import request_password_reset
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="password_reset_request")


def _header(event, name):
    target = name.lower()
    for key, value in (event.get("headers") or {}).items():
        if key.lower() == target:
            return value
    return ""


def _reset_base_url(event):
    configured = (os.getenv("PASSWORD_RESET_BASE_URL") or "").strip()
    if configured:
        return configured.rstrip("/")

    origin = (_header(event, "origin") or "").strip()
    if origin:
        return origin.rstrip("/")

    return ""


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["email"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            result = request_password_reset(
                connection,
                payload["email"],
                source_email=(os.getenv("PASSWORD_RESET_FROM_EMAIL") or "").strip(),
                reset_base_url=_reset_base_url(event),
            )
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except Exception:
        logger.exception("Password reset request failed")
        return error_response(500, "PASSWORD_RESET_FAILED", "Unable to request password reset right now")

    logger.info("Password reset request accepted email_sent=%s", result.get("email_sent"))
    return success_response(202, {"accepted": True})
