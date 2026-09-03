from common.root_admin_logic import search_root_admin_organizations
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    query = ((event.get("queryStringParameters") or {}).get("q") or "").strip()

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            organizations = search_root_admin_organizations(connection, query)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    return success_response(200, {"organizations": organizations})
