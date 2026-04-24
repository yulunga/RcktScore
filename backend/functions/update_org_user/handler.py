from aws_lambda_powertools import Logger

from common.organization_logic import update_organization_user_role
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


logger = Logger(service="update_org_user")


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    if not user_id:
        return error_response(400, "VALIDATION_ERROR", "user_id path parameter is required")

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "role"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_organization_session(connection, event, payload["organization_id"], require_admin=True)
            user = update_organization_user_role(connection, payload["organization_id"], user_id, payload["role"])
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    if not user:
        return error_response(404, "USER_NOT_FOUND", "User not found")

    logger.info("Updated organisation user %s", user_id)
    return success_response(200, {"user": user})
