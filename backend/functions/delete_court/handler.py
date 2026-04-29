from aws_lambda_powertools import Logger

from common.organization_logic import delete_court
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    is_root_admin_request,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


logger = Logger(service="delete_court")


def lambda_handler(event, context):
    court_id = path_parameter(event, "court_id")
    if not court_id:
        return error_response(400, "VALIDATION_ERROR", "court_id path parameter is required")

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            if not is_root_admin_request(event):
                authorize_organization_session(connection, event, payload["organization_id"], require_admin=True)
            deleted = delete_court(connection, payload["organization_id"], court_id)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not deleted:
        return error_response(404, "COURT_NOT_FOUND", "Court not found")

    logger.info("Deleted court %s", court_id)
    return success_response(200, {"deleted": True})
