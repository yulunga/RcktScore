from aws_lambda_powertools import Logger

from common.match_logic import create_match, websocket_payload
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, require_fields


logger = Logger(service="create_match")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(
        payload,
        ["tenant_id", "court_id", "court_name", "player1_name", "player2_name"],
    )
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    with get_db_connection() as connection:
        match = create_match(connection, payload, source="lambda")

    logger.info("Created match %s", match["id"])
    return json_response(201, {"match": match, "broadcast": websocket_payload(match)})
