from common.match_setup_logic import search_match_setup_lookups
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    query = ((event.get("queryStringParameters") or {}).get("q") or "").strip()

    with get_db_connection() as connection:
        lookups = search_match_setup_lookups(connection, organization_id, query)

    return success_response(200, {"lookups": lookups})
