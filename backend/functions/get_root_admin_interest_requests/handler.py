from common.root_admin_logic import get_root_admin_interest_requests
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    query_params = event.get("queryStringParameters") or {}
    status = query_params.get("status")

    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            interest_requests = get_root_admin_interest_requests(connection, status)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    return success_response(200, {"interestRequests": interest_requests})
