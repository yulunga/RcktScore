from aws_lambda_powertools import Logger

from common.organization_logic import update_court
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


logger = Logger(service="update_court")


def lambda_handler(event, context):
    court_id = path_parameter(event, "court_id")
    if not court_id:
        return error_response(400, "VALIDATION_ERROR", "court_id path parameter is required")

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "court_name"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_organization_session(connection, event, payload["organization_id"], require_admin=True)
            court = update_court(
                connection,
                payload["organization_id"],
                court_id,
                payload["court_name"],
                payload.get("court_alias"),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    if not court:
        return error_response(404, "COURT_NOT_FOUND", "Court not found")

    logger.info("Updated court %s", court_id)
    return success_response(200, {"court": court})
