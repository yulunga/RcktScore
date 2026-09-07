from common.root_admin_logic import remove_root_admin_user_club_membership
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    membership_id = path_parameter(event, "membership_id")
    if not user_id or not membership_id:
        return error_response(400, "VALIDATION_ERROR", "User ID and membership ID are required")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            result = remove_root_admin_user_club_membership(
                connection,
                int(user_id),
                int(membership_id),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except (TypeError, ValueError) as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))

    return success_response(200, result)
