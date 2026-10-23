from urllib.parse import unquote

from common.root_admin_logic import delete_root_admin_association_competition
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    name = unquote(path_parameter(event, "competition_name") or "").strip()
    if not name:
        return error_response(400, "VALIDATION_ERROR", "competition_name is required")
    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            result = delete_root_admin_association_competition(connection, name)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    return success_response(200, result)
