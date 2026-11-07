from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            session = require_root_admin_session(connection, event)
        return success_response(
            200,
            {
                "rootAdminSession": {
                    "id": session["id"],
                    "username": session["username"],
                    "role": "root_admin",
                    "expires_at": session["expires_at"],
                    "csrf_token": session.get("csrf_token"),
                }
            },
        )
    except SessionAuthError as session_error:
        return session_error_response(session_error)
