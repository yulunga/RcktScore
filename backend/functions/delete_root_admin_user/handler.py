from common.root_admin_logic import delete_root_admin_user_account
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


REQUIRED_CONFIRMATION = "DELETE USER"


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    payload = parse_body(event)
    if not user_id or (payload.get("confirmation") or "").strip() != REQUIRED_CONFIRMATION:
        return error_response(400, "INVALID_CONFIRMATION", "User account deletion was not confirmed")
    try:
        numeric_user_id = int(user_id)
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "User ID must be a number")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            result = delete_root_admin_user_account(
                connection,
                numeric_user_id,
                delete_games=bool(payload.get("delete_games")),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except LookupError as request_error:
        return error_response(404, "USER_NOT_FOUND", str(request_error))
    except Exception:
        return error_response(500, "USER_DELETE_FAILED", "Unable to delete this user account right now")

    return success_response(200, result)
