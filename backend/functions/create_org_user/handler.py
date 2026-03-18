from aws_lambda_powertools import Logger

from common.organization_logic import create_organization_user
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="create_org_user")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "username", "password", "role"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            user = create_organization_user(
                connection,
                payload["organization_id"],
                payload["username"],
                payload["password"],
                payload["role"],
            )
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    logger.info("Created organisation user for organization_id=%s", payload["organization_id"])
    return success_response(201, {"user": user})
