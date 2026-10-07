from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.tournament.access import set_tournament_feature
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    payload = parse_body(event)
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")
    if not isinstance(payload.get("web_enabled"), bool):
        return error_response(400, "VALIDATION_ERROR", "web_enabled must be true or false")

    try:
        with get_db_connection() as connection:
            session = require_root_admin_session(connection, event)
            feature = set_tournament_feature(
                connection,
                organization_id,
                payload["web_enabled"],
                session.get("username") or "root_admin",
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except LookupError as request_error:
        return error_response(404, "ORGANIZATION_NOT_FOUND", str(request_error))
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    return success_response(200, {"tournamentFeature": feature})

