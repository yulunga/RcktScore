from aws_lambda_powertools import Logger

from common.match_logic import end_match
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, require_fields


logger = Logger(service="end_match")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["match_id"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    with get_db_connection() as connection:
        match = end_match(connection, payload["match_id"], source=payload.get("source", "lambda"))

    if not match:
        return json_response(404, {"message": "Match not found"})

    logger.info("Ended match %s", payload["match_id"])
    return json_response(200, {"match": match})
