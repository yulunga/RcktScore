from common.root_admin_logic import get_root_admin_personal_accounts
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    query_params = event.get("queryStringParameters") or {}
    plan = query_params.get("plan")

    with get_db_connection() as connection:
        personal_accounts = get_root_admin_personal_accounts(connection, plan)

    return success_response(200, {"personalAccounts": personal_accounts})
