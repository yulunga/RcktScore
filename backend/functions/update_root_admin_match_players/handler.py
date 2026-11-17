from uuid import UUID

from common.root_admin_logic import correct_root_admin_match_players
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
            root_admin = require_root_admin_session(connection, event)
            payload = parse_body(event)
            if not isinstance(payload, dict):
                raise ValueError("Request body must be an object")
            match = correct_root_admin_match_players(
                connection,
                UUID(match_id),
                payload,
                updated_by=root_admin.get("username"),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))
    except (TypeError, ValueError) as request_error:
        return error_response(400, "VALIDATION_ERROR", str(request_error) or "Invalid request")

    return success_response(200, {"match": match})
