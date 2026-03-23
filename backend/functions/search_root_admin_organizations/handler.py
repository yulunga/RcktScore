from common.root_admin_logic import search_root_admin_organizations
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    query = ((event.get("queryStringParameters") or {}).get("q") or "").strip()

    with get_db_connection() as connection:
        organizations = search_root_admin_organizations(connection, query)

    return success_response(200, {"organizations": organizations})
