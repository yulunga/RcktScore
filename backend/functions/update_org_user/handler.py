from aws_lambda_powertools import Logger

from common.organization_logic import update_organization_user_role
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, path_parameter, require_fields


logger = Logger(service="update_org_user")


def lambda_handler(event, context):
    user_id = path_parameter(event, "user_id")
    if not user_id:
        return json_response(400, {"message": "user_id path parameter is required"})

    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "role"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    try:
        with get_db_connection() as connection:
            user = update_organization_user_role(connection, payload["organization_id"], user_id, payload["role"])
    except ValueError as request_error:
        return json_response(400, {"message": str(request_error)})

    if not user:
        return json_response(404, {"message": "User not found"})

    logger.info("Updated organisation user %s", user_id)
    return json_response(200, {"user": user})
