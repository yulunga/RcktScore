import os

from aws_lambda_powertools import Logger

from common.organization_logic import create_organization_user
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, request_base_url, require_fields, success_response


logger = Logger(service="create_org_user")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "username", "role"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_organization_session(connection, event, payload["organization_id"], require_admin=True)
            user = create_organization_user(
                connection,
                payload["organization_id"],
                payload["username"],
                payload.get("password"),
                payload["role"],
                allow_existing_password_reuse=True,
                invitation_source_email=(os.getenv("USER_INVITATION_FROM_EMAIL") or "").strip() or None,
                approval_base_url=request_base_url(event),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except Exception as request_error:
        logger.exception("Failed to create organisation user")
        return error_response(500, "INVITATION_FAILED", str(request_error))

    logger.info("Created organisation user for organization_id=%s", payload["organization_id"])
    return success_response(201, {"user": user})
