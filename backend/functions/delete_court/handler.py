from aws_lambda_powertools import Logger

from common.organization_logic import delete_court
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, path_parameter, require_fields


logger = Logger(service="delete_court")


def lambda_handler(event, context):
    court_id = path_parameter(event, "court_id")
    if not court_id:
        return json_response(400, {"message": "court_id path parameter is required"})

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    with get_db_connection() as connection:
        deleted = delete_court(connection, payload["organization_id"], court_id)

    if not deleted:
        return json_response(404, {"message": "Court not found"})

    logger.info("Deleted court %s", court_id)
    return json_response(200, {"deleted": True})
