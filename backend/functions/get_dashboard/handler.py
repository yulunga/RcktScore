from aws_lambda_powertools import Logger

from common.dashboard_logic import get_dashboard_data
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_dashboard")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    with get_db_connection() as connection:
        dashboard = get_dashboard_data(connection, organization_id)

    logger.info("Fetched dashboard data for organization_id=%s", organization_id)
    return success_response(200, {"dashboard": dashboard})
