import os

from common.root_admin_logic import add_root_admin_user_club_membership
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, request_base_url, require_fields, success_response


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "role"])
    if not user_id or missing_fields:
        return error_response(
            400,
            "VALIDATION_ERROR",
            "User ID, organization_id and role are required",
            {"fields": missing_fields},
        )

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            membership = add_root_admin_user_club_membership(
                connection,
                int(user_id),
                payload["organization_id"],
                payload["role"],
                invitation_source_email=(os.getenv("USER_INVITATION_FROM_EMAIL") or "").strip() or None,
                approval_base_url=request_base_url(event),
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except (TypeError, ValueError) as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))
    except Exception as request_error:
        return error_response(500, "INVITATION_FAILED", str(request_error))

    return success_response(201, {"membership": membership})
