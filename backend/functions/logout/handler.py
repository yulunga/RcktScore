from common.session_logic import (
    SessionAuthError,
    clear_session_cookie,
    require_org_user_session,
    revoke_org_user_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            session = require_org_user_session(connection, event)
            token = session["token"]
            revoke_org_user_session(connection, token, reason="logout")
    except SessionAuthError as session_error:
        return session_error_response(session_error)

    return success_response(200, {"logged_out": True}, cookies=[clear_session_cookie()])
