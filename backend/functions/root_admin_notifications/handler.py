from common.notification_center_logic import create_notification, list_admin_notifications
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


def lambda_handler(event, context):
    method = (event.get("requestContext", {}).get("http", {}).get("method") or "GET").upper()
    try:
        with get_db_connection() as connection:
            admin = require_root_admin_session(connection, event)
            if method == "POST":
                payload = parse_body(event)
                notification = create_notification(
                    connection,
                    payload.get("title"),
                    payload.get("message"),
                    payload.get("audience"),
                    admin["username"],
                )
                return success_response(201, {"notification": notification})
            return success_response(200, {"notifications": list_admin_notifications(connection)})
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
