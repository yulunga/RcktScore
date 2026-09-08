from common.notification_center_logic import list_user_notifications
from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id is required")
    try:
        with get_db_connection() as connection:
            auth = authorize_organization_session(connection, event, organization_id)
            membership = auth["membership"]
            notifications = list_user_notifications(
                connection,
                auth["session"]["username"],
                membership.get("plan") or "club_essentials",
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    return success_response(200, {"notifications": notifications})
