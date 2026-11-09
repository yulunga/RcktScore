from uuid import UUID

from common.root_admin_logic import delete_root_admin_match
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            payload = parse_body(event)
            if not isinstance(payload, dict) or payload.get("confirmation") != "DELETE":
                return error_response(400, "INVALID_CONFIRMATION", "Type DELETE to confirm")
            deleted_match = delete_root_admin_match(connection, UUID(match_id))
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError:
        return error_response(400, "VALIDATION_ERROR", "Invalid match ID or request body")
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))

    return success_response(200, {"deletedMatch": deleted_match})
