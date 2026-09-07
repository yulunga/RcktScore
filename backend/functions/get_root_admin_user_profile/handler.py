from common.root_admin_logic import get_root_admin_user_profile
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    if not user_id:
        return error_response(400, "VALIDATION_ERROR", "User ID is required")

    try:
        numeric_user_id = int(user_id)
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "User ID must be a number")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            profile = get_root_admin_user_profile(connection, numeric_user_id)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not profile:
        return error_response(404, "USER_NOT_FOUND", "User not found")
    return success_response(200, {"userProfile": profile})
