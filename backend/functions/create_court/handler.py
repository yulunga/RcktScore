from aws_lambda_powertools import Logger

from common.organization_logic import create_court
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="create_court")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "court_name"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_organization_session(connection, event, payload["organization_id"], require_admin=True)
            court = create_court(
                connection,
                payload["organization_id"],
                payload["court_name"],
                payload.get("court_alias"),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    logger.info("Created court for organization_id=%s", payload["organization_id"])
    return success_response(201, {"court": court})
