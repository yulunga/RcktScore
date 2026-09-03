from common.root_admin_logic import get_root_admin_matches
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


def lambda_handler(event, context):
    query_params = event.get("queryStringParameters") or {}
    sport = query_params.get("sport")
    organization_id = query_params.get("organization_id")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            root_admin_matches = get_root_admin_matches(
                connection,
                sport=sport,
                organization_id=organization_id,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError:
        return error_response(400, "VALIDATION_ERROR", "organization_id must be a number")

    return success_response(200, {"rootAdminMatches": root_admin_matches})
