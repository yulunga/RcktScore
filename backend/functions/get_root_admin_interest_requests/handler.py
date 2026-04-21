from common.root_admin_logic import get_root_admin_interest_requests
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    query_params = event.get("queryStringParameters") or {}
    status = query_params.get("status")

    with get_db_connection() as connection:
        interest_requests = get_root_admin_interest_requests(connection, status)

    return success_response(200, {"interestRequests": interest_requests})
