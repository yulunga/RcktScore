from common.root_admin_session_logic import (
    clear_root_admin_session_cookie,
    require_root_admin_session,
    revoke_root_admin_session,
)
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            session = require_root_admin_session(connection, event)
            revoke_root_admin_session(connection, session["token"], reason="logout")
    except SessionAuthError as session_error:
        return session_error_response(session_error)

    return success_response(200, {"logged_out": True}, cookies=[clear_root_admin_session_cookie()])
