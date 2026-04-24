from aws_lambda_powertools import Logger

from common.organization_logic import update_personal_profile
from common.session_logic import (
    SessionAuthError,
    authorize_personal_profile_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


logger = Logger(service="update_personal_profile")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["username"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_personal_profile_session(connection, event, organization_id, payload["username"])
            settings = update_personal_profile(connection, organization_id, payload["username"], payload)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    if not settings:
        return error_response(404, "ORGANIZATION_NOT_FOUND", "Personal account not found")

    logger.info("Updated personal profile for organization_id=%s", organization_id)
    return success_response(200, {"organizationSettings": settings})
