from aws_lambda_powertools import Logger

from common.organization_logic import create_court
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, require_fields


logger = Logger(service="create_court")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "court_name"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    try:
        with get_db_connection() as connection:
            court = create_court(
                connection,
                payload["organization_id"],
                payload["court_name"],
                payload.get("court_alias"),
            )
    except ValueError as request_error:
        return json_response(400, {"message": str(request_error)})

    logger.info("Created court for organization_id=%s", payload["organization_id"])
    return json_response(201, {"court": court})
