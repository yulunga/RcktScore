from common.root_admin_logic import verify_root_admin_user_email
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
            root_admin = require_root_admin_session(connection, event)
            result = verify_root_admin_user_email(
                connection,
                numeric_user_id,
                root_admin.get("username"),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except LookupError as request_error:
        return error_response(404, "USER_NOT_FOUND", str(request_error))

    return success_response(200, result)
