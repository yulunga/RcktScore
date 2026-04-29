from aws_lambda_powertools import Logger

from common.organization_logic import get_organization_settings
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    is_root_admin_request,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_organization_settings")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    try:
        with get_db_connection() as connection:
            if not is_root_admin_request(event):
                authorize_organization_session(connection, event, organization_id, require_admin=False)
            settings = get_organization_settings(connection, organization_id)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not settings:
        return error_response(404, "ORGANIZATION_NOT_FOUND", "Organisation not found")

    logger.info("Fetched organisation settings for organization_id=%s", organization_id)
    return success_response(200, {"organizationSettings": settings})
