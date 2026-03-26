from aws_lambda_powertools import Logger

from common.match_logic import activate_scheduled_match, websocket_payload
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


logger = Logger(service="start_scheduled_match")


def lambda_handler(event, context):
    payload = parse_body(event)
    match_id = (payload.get("match_id") or "").strip()
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id is required")

    with get_db_connection() as connection:
        match = activate_scheduled_match(connection, match_id)

    if not match:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Activated scheduled match %s", match["id"])
    return success_response(200, {"match": match, "broadcast": websocket_payload(match)})
