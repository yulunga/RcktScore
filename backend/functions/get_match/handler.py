from aws_lambda_powertools import Logger

from common.match_logic import get_match, websocket_payload
from common.supabase_client import get_db_connection
from common.utils import json_response, path_parameter


logger = Logger(service="get_match")


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return json_response(400, {"message": "match_id path parameter is required"})

    with get_db_connection() as connection:
        match = get_match(connection, match_id)

    if not match:
        return json_response(404, {"message": "Match not found"})

    logger.info("Fetched match %s", match_id)
    return json_response(200, {"match": match, "broadcast": websocket_payload(match)})
