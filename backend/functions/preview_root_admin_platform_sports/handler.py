from common.root_admin_logic import preview_root_admin_platform_sports
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


def lambda_handler(event, context):
    payload = parse_body(event)
    if "enabled_sports_web" not in payload or "enabled_sports_ios" not in payload:
        return error_response(400, "VALIDATION_ERROR", "Web and iOS sport lists are required")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            preview = preview_root_admin_platform_sports(
                connection,
                payload.get("enabled_sports_web"),
                payload.get("enabled_sports_ios"),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    return success_response(200, {"platformSportsPreview": preview})
