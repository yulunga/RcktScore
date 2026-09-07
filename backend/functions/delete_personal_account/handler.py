from aws_lambda_powertools import Logger

from common.organization_logic import delete_personal_account
from common.session_logic import (
    SessionAuthError,
    authorize_personal_profile_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, require_fields, success_response


logger = Logger(service="delete_personal_account")
REQUIRED_CONFIRMATION = "DELETE MY ACCOUNT"


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["confirmation"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Deletion confirmation is required")
    if (payload.get("confirmation") or "").strip() != REQUIRED_CONFIRMATION:
        return error_response(400, "INVALID_CONFIRMATION", "Account deletion was not confirmed")

    try:
        with get_db_connection() as connection:
            auth_context = authorize_personal_profile_session(connection, event, organization_id)
            delete_personal_account(
                connection,
                organization_id,
                auth_context["session"]["username"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(403, "ACCOUNT_DELETION_FORBIDDEN", str(request_error))
    except Exception:
        logger.exception("Personal account deletion failed")
        return error_response(500, "ACCOUNT_DELETION_FAILED", "Unable to delete the account right now")

    logger.info("Deleted personal account for organization_id=%s", organization_id)
    return success_response(200, {"deleted": True})
