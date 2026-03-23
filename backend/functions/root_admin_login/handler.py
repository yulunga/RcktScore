from aws_lambda_powertools import Logger

from common.auth_logic import authenticate_root_admin
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="root_admin_login")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["username", "password"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    username = payload["username"].strip()
    password = payload["password"]

    with get_db_connection() as connection:
        user = authenticate_root_admin(connection, username, password)

    if not user:
        logger.warning("Invalid root admin login attempt for username=%s", username)
        return error_response(401, "INVALID_CREDENTIALS", "Invalid credentials")

    logger.info("Authenticated root admin id=%s", user["id"])
    return success_response(200, {"rootAdminSession": user})
