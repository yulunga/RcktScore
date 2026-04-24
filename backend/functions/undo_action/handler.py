from aws_lambda_powertools import Logger

from common.match_logic import undo_last_action, websocket_payload
from common.session_logic import SessionAuthError, authorize_match_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="undo_action")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["match_id"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_match_session(connection, event, payload["match_id"])
            match = undo_last_action(connection, payload["match_id"])
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not match:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Undid last action on match %s", payload["match_id"])
    return success_response(200, {"match": match, "broadcast": websocket_payload(match)})
