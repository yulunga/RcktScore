from aws_lambda_powertools import Logger

from common.auth_logic import authenticate_org_user
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, require_fields


logger = Logger(service="login")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["username", "password"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    username = payload["username"].strip()
    password = payload["password"]

    with get_db_connection() as connection:
        user = authenticate_org_user(connection, username, password)

    if not user:
        logger.warning("Invalid login attempt for username=%s", username)
        return json_response(401, {"message": "Invalid credentials"})

    logger.info("Authenticated org user id=%s organization_id=%s", user["id"], user["organization_id"])
    return json_response(200, {"session": user})
