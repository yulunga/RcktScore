from aws_lambda_powertools import Logger

from common.scoreboard_logic import DisplaySessionError, approve_scoreboard_pairing
from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


logger = Logger(service="approve_scoreboard_pairing")


def lambda_handler(event, context):
    court_id = path_parameter(event, "court_id")
    payload = parse_body(event)
    organization_id = payload.get("organization_id")
    token = payload.get("token")
    if not court_id or not organization_id or not token:
        return error_response(400, "VALIDATION_ERROR", "court_id, organization_id and token are required")

    try:
        with get_db_connection() as connection:
            auth_context = authorize_organization_session(
                connection,
                event,
                organization_id,
                require_admin=True,
                allow_root_admin=False,
            )
            membership = auth_context["membership"]
            approval = approve_scoreboard_pairing(
                connection,
                organization_id,
                court_id,
                membership["id"],
                token,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except DisplaySessionError as pairing_error:
        return error_response(pairing_error.status_code, pairing_error.code, pairing_error.message, pairing_error.details)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    logger.info("Approved scoreboard QR pairing for court %s", court_id)
    return success_response(200, {"pairing": approval})
