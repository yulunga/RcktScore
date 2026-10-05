from common.root_admin_logic import update_root_admin_user_sport_access
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    membership_id = path_parameter(event, "membership_id")
    payload = parse_body(event)
    if not user_id or not membership_id:
        return error_response(400, "VALIDATION_ERROR", "User and membership IDs are required")
    if "enabled_sports_web" not in payload or "enabled_sports_ios" not in payload:
        return error_response(400, "VALIDATION_ERROR", "Web and iOS sport lists are required")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            access = update_root_admin_user_sport_access(
                connection,
                user_id,
                membership_id,
                enabled_sports_web=payload.get("enabled_sports_web"),
                enabled_sports_ios=payload.get("enabled_sports_ios"),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except (TypeError, ValueError):
        return error_response(400, "INVALID_INPUT", "User and membership IDs must be valid")

    if not access:
        return error_response(404, "MEMBERSHIP_NOT_FOUND", "User membership was not found")
    return success_response(200, {"sportAccess": access})
