from aws_lambda_powertools import Logger

from common.dashboard_logic import personal_free_can_access_completed_match
from common.match_logic import get_match, websocket_payload
from common.session_logic import SessionAuthError, authorize_match_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_match")


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    try:
        with get_db_connection() as connection:
            auth_context = authorize_match_session(connection, event, match_id)
            match = get_match(connection, match_id)
            membership = auth_context.get("membership") or {}
            if (
                match
                and match.get("status") == "completed"
                and membership.get("organization_type") == "personal"
                and membership.get("plan") == "personal_free"
                and not personal_free_can_access_completed_match(
                    connection,
                    auth_context["tenant_id"],
                    match_id,
                )
            ):
                return error_response(
                    403,
                    "PERSONAL_PLUS_REQUIRED",
                    "Upgrade to Personal Plus to open this match from your full history.",
                )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not match:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Fetched match %s", match_id)
    return success_response(200, {"match": match, "broadcast": websocket_payload(match)})
