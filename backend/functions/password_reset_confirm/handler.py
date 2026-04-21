from aws_lambda_powertools import Logger

from common.password_reset_logic import confirm_password_reset
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="password_reset_confirm")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["token", "password"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            result = confirm_password_reset(connection, payload["token"], payload["password"])
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except Exception:
        logger.exception("Password reset confirm failed")
        return error_response(500, "PASSWORD_RESET_FAILED", "Unable to reset password right now")

    logger.info("Password reset confirmed")
    return success_response(200, result)
