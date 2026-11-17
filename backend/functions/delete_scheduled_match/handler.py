from common.access_control import CAPABILITY_CLUB_SETTINGS_WRITE
from common.scheduled_match_logic import delete_scheduled_club_match
from common.session_logic import SessionAuthError, authorize_match_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    try:
        with get_db_connection() as connection:
            auth_context = authorize_match_session(
                connection,
                event,
                match_id,
                required_capability=CAPABILITY_CLUB_SETTINGS_WRITE,
            )
            membership = auth_context["membership"]
            if membership.get("organization_type") != "club":
                return error_response(403, "CLUB_ADMIN_REQUIRED", "A club administrator is required")
            deleted_match = delete_scheduled_club_match(
                connection,
                match_id,
                auth_context["tenant_id"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except LookupError as request_error:
        return error_response(404, "MATCH_NOT_FOUND", str(request_error))
    except ValueError as request_error:
        return error_response(409, "SCHEDULED_MATCH_DELETE_DENIED", str(request_error))

    return success_response(200, {"deletedMatch": deleted_match})
