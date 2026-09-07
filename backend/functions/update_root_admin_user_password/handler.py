from common.root_admin_logic import update_root_admin_user_password
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["password"])
    if not user_id or missing_fields:
        return error_response(400, "VALIDATION_ERROR", "User ID and password are required")

    try:
        numeric_user_id = int(user_id)
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "User ID must be a number")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            result = update_root_admin_user_password(connection, numeric_user_id, payload["password"])
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except LookupError as request_error:
        return error_response(404, "USER_NOT_FOUND", str(request_error))

    return success_response(200, result)
