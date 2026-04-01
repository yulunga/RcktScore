import os

from common.root_admin_logic import create_root_admin_org_user
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, request_base_url, require_fields, success_response


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "username", "role"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            user = create_root_admin_org_user(
                connection,
                payload["organization_id"],
                payload["username"],
                payload.get("password"),
                payload["role"],
                invitation_source_email=(os.getenv("USER_INVITATION_FROM_EMAIL") or "").strip() or None,
                approval_base_url=request_base_url(event),
            )
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except Exception as request_error:
        return error_response(500, "INVITATION_FAILED", str(request_error))

    return success_response(201, {"user": user})
