from aws_lambda_powertools import Logger

from common.organization_logic import update_organization_details
from common.supabase_client import get_db_connection
from common.utils import json_response, parse_body, path_parameter


logger = Logger(service="update_organization_details")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return json_response(400, {"message": "organization_id path parameter is required"})

    payload = parse_body(event)

    with get_db_connection() as connection:
        settings = update_organization_details(connection, organization_id, payload)

    if not settings:
        return json_response(404, {"message": "Organisation not found"})

    logger.info("Updated organisation details for organization_id=%s", organization_id)
    return json_response(200, settings)
