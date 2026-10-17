from aws_lambda_powertools import Logger

from common.match_watch_logic import MatchWatchError, ensure_personal_plus, save_watched_match
from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


logger = Logger(service="save_watched_match")


def lambda_handler(event, context):
    payload = parse_body(event)
    organization_id = payload.get("organization_id")
    code = payload.get("code")
    if not organization_id or not code:
        return error_response(400, "VALIDATION_ERROR", "organization_id and code are required")

    try:
        with get_db_connection() as connection:
            auth_context = authorize_organization_session(connection, event, organization_id, require_admin=False)
            ensure_personal_plus(auth_context["membership"])
            watch = save_watched_match(
                connection,
                organization_id,
                (auth_context.get("session") or {}).get("username"),
                code,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except MatchWatchError as watch_error:
        return error_response(watch_error.status_code, watch_error.code, watch_error.message)

    logger.info("Saved watched match for organization_id=%s", organization_id)
    return success_response(200, {"watch": watch})
