from aws_lambda_powertools import Logger

from common.organization_logic import update_organization_details
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


logger = Logger(service="update_organization_details")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    payload = parse_body(event)

    with get_db_connection() as connection:
        settings = update_organization_details(connection, organization_id, payload)

    if not settings:
        return error_response(404, "ORGANIZATION_NOT_FOUND", "Organisation not found")

    logger.info("Updated organisation details for organization_id=%s", organization_id)
    return success_response(200, {"organizationSettings": settings})
