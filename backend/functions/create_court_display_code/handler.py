from aws_lambda_powertools import Logger

from common.organization_logic import get_organization_settings
from common.scoreboard_logic import issue_court_display_code
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    is_root_admin_request,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


logger = Logger(service="create_court_display_code")


def lambda_handler(event, context):
    court_id = path_parameter(event, "court_id")
    if not court_id:
        return error_response(400, "VALIDATION_ERROR", "court_id path parameter is required")

    payload = parse_body(event)
    organization_id = payload.get("organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id is required")

    include_display_codes = True
    try:
        with get_db_connection() as connection:
            if not is_root_admin_request(event):
                authorize_organization_session(connection, event, organization_id, require_admin=True)
            court = issue_court_display_code(connection, organization_id, court_id)
            settings = get_organization_settings(
                connection,
                organization_id,
                include_display_codes=include_display_codes,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    if not court:
        return error_response(404, "COURT_NOT_FOUND", "Court not found")

    logger.info("Generated display code for court %s", court_id)
    return success_response(
        200,
        {
            "court": court,
            "organizationSettings": settings,
        },
    )
