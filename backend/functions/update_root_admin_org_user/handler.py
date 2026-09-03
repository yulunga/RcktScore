from common.root_admin_logic import update_root_admin_org_user_role
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    if not user_id:
        return error_response(400, "VALIDATION_ERROR", "user_id path parameter is required")

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "role"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            user = update_root_admin_org_user_role(
                connection,
                payload["organization_id"],
                user_id,
                payload["role"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    if not user:
        return error_response(404, "USER_NOT_FOUND", "User not found")

    return success_response(200, {"user": user})
