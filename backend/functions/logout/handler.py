from common.session_logic import revoke_org_user_session, session_token_from_event
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    token = session_token_from_event(event)
    if token:
        with get_db_connection() as connection:
            revoke_org_user_session(connection, token, reason="logout")

    return success_response(200, {"logged_out": True})
