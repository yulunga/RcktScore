from common.notification_center_logic import mark_notification_read
from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    notification_id = path_parameter(event, "notification_id")
    payload = parse_body(event)
    organization_id = payload.get("organization_id")
    if not notification_id or not organization_id:
        return error_response(400, "VALIDATION_ERROR", "notification_id and organization_id are required")
    try:
        with get_db_connection() as connection:
            auth = authorize_organization_session(connection, event, organization_id)
            membership = auth["membership"]
            updated = mark_notification_read(
                connection,
                notification_id,
                auth["session"]["username"],
                membership.get("plan") or "club_essentials",
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    if not updated:
        return error_response(404, "NOTIFICATION_NOT_FOUND", "Notification not found")
    return success_response(200, {"read": True})
