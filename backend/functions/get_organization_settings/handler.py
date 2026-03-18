from aws_lambda_powertools import Logger

from common.organization_logic import get_organization_settings
from common.supabase_client import get_db_connection
from common.utils import json_response, path_parameter


logger = Logger(service="get_organization_settings")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return json_response(400, {"message": "organization_id path parameter is required"})

    with get_db_connection() as connection:
        settings = get_organization_settings(connection, organization_id)

    if not settings:
        return json_response(404, {"message": "Organisation not found"})

    logger.info("Fetched organisation settings for organization_id=%s", organization_id)
    return json_response(200, settings)
