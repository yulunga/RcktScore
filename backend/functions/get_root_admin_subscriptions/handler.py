from common.root_admin_session_logic import require_root_admin_session
from common.root_admin_subscription_logic import get_root_admin_subscriptions
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


def lambda_handler(event, context):
    organization_id = (event.get("queryStringParameters") or {}).get("organization_id")
    try:
        parsed_organization_id = int(organization_id) if organization_id else None
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            result = get_root_admin_subscriptions(connection, parsed_organization_id)
    except SessionAuthError as error:
        return session_error_response(error)
    except ValueError:
        return error_response(400, "VALIDATION_ERROR", "organization_id must be a number")
    return success_response(200, {"rootAdminSubscriptions": result})
