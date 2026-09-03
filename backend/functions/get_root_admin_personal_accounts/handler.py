from common.root_admin_logic import get_root_admin_personal_accounts
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    query_params = event.get("queryStringParameters") or {}
    plan = query_params.get("plan")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            personal_accounts = get_root_admin_personal_accounts(connection, plan)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    return success_response(200, {"personalAccounts": personal_accounts})
