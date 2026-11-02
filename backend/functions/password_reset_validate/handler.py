from aws_lambda_powertools import Logger

from common.password_reset_logic import validate_password_reset_token
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="password_reset_validate")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["token"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Reset token is required")

    try:
        with get_db_connection() as connection:
            result = validate_password_reset_token(connection, payload["token"])
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except Exception:
        logger.exception("Password reset token validation failed")
        return error_response(500, "PASSWORD_RESET_VALIDATION_FAILED", "Unable to validate this link right now")

    return success_response(200, result)
