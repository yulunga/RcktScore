from aws_lambda_powertools import Logger

from common.match_logic import undo_last_action, websocket_payload
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, require_fields


logger = Logger(service="undo_action")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["match_id"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    with get_db_connection() as connection:
        match = undo_last_action(connection, payload["match_id"])

    if not match:
        return json_response(404, {"message": "Match not found"})

    logger.info("Undid last action on match %s", payload["match_id"])
    return json_response(200, {"match": match, "broadcast": websocket_payload(match)})
