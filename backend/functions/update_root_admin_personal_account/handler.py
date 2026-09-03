from common.root_admin_logic import update_root_admin_personal_account_settings
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    payload = parse_body(event)
    request_id = path_parameter(event, "request_id")

    if not request_id:
        return error_response(400, "VALIDATION_ERROR", "Personal account ID is required")

    try:
        numeric_request_id = int(request_id)
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "Personal account ID must be a number")

    try:
        with get_db_connection() as connection:
            root_admin_session = require_root_admin_session(connection, event)
            personal_account = update_root_admin_personal_account_settings(
                connection,
                numeric_request_id,
                personal_plan=payload.get("personal_plan"),
                enabled_sports=payload.get("enabled_sports"),
                updated_by=root_admin_session["username"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))

    return success_response(200, {"personalAccount": personal_account})
