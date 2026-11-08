from common.access_control import CAPABILITY_MATCH_MANAGE
from common.analytics_logic import begin_match_setup, finish_match_setup
from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    setup_id = path_parameter(event, "setup_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    payload = parse_body(event)
    try:
        with get_db_connection() as connection:
            auth = authorize_organization_session(
                connection,
                event,
                organization_id,
                required_capability=CAPABILITY_MATCH_MANAGE,
            )
            membership = auth["membership"]
            if setup_id:
                result = finish_match_setup(
                    connection,
                    setup_id,
                    organization_id,
                    membership["id"],
                    payload.get("outcome"),
                    payload.get("match_id"),
                )
                if not result:
                    return error_response(404, "MATCH_SETUP_SESSION_NOT_FOUND", "Match setup session not found")
                return success_response(200, {"setup": result})

            result = begin_match_setup(
                connection,
                organization_id,
                membership["id"],
                auth["session"].get("login_source"),
                payload.get("sport"),
            )
            return success_response(201, {"setup": result})
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as validation_error:
        return error_response(400, "VALIDATION_ERROR", str(validation_error))
