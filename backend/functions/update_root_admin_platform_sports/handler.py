from common.root_admin_logic import update_root_admin_platform_sports
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


def lambda_handler(event, context):
    payload = parse_body(event)

    if "enabled_sports" not in payload:
        return error_response(400, "VALIDATION_ERROR", "enabled_sports is required")

    try:
        with get_db_connection() as connection:
            root_admin_session = require_root_admin_session(connection, event)
            platform_sports = update_root_admin_platform_sports(
                connection,
                payload.get("enabled_sports"),
                updated_by=root_admin_session["username"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    return success_response(200, {"platformSports": platform_sports})
