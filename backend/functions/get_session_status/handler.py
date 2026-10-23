from common.session_logic import SessionAuthError, require_org_user_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            session = require_org_user_session(connection, event)
        return success_response(
            200,
            {
                "active": True,
                "login_source": session.get("login_source"),
            },
        )
    except SessionAuthError as session_error:
        return session_error_response(session_error)
