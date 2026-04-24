from aws_lambda_powertools import Logger

from common.match_logic import score_point, websocket_payload
from common.session_logic import SessionAuthError, authorize_match_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="score_point")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["match_id", "scorer"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_match_session(connection, event, payload["match_id"])
            try:
                match = score_point(connection, payload["match_id"], payload["scorer"], source=payload.get("source", "lambda"))
            except ValueError as exc:
                return error_response(400, "INVALID_INPUT", str(exc))
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not match:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Scored point on match %s", payload["match_id"])
    return success_response(200, {"match": match, "broadcast": websocket_payload(match)})
