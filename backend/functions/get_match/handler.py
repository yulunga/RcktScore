from aws_lambda_powertools import Logger

from common.match_logic import get_match, websocket_payload
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_match")


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    with get_db_connection() as connection:
        match = get_match(connection, match_id)

    if not match:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Fetched match %s", match_id)
    return success_response(200, {"match": match, "broadcast": websocket_payload(match)})
