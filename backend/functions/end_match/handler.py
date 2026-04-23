from aws_lambda_powertools import Logger

from common.match_logic import end_match
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="end_match")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["match_id"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    with get_db_connection() as connection:
        match = end_match(
            connection,
            payload["match_id"],
            source=payload.get("source", "lambda"),
            reason=payload.get("reason"),
            ended_early=payload.get("ended_early"),
            match_duration_seconds=payload.get("match_duration_seconds"),
        )

    if not match:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Ended match %s", payload["match_id"])
    return success_response(200, {"match": match})
