from common.auth_logic import _serialize_org_user, get_org_users
from common.session_logic import SessionAuthError, require_org_user_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            session = require_org_user_session(connection, event)
            memberships = [
                _serialize_org_user(row, client_type=session["login_source"])
                for row in get_org_users(connection, session["username"], False)
                if (row.get("approval_status") or "approved") == "approved"
            ]
            selected = next(
                (membership for membership in memberships if membership.get("organization_type") == "personal"),
                memberships[0] if memberships else {},
            )
            session_payload = {
                **selected,
                "available_memberships": memberships,
                "session_expires_at": session["expires_at"].isoformat(),
            }
            if session.get("credential_type") == "cookie":
                session_payload["csrf_token"] = session.get("csrf_token")
        return success_response(
            200,
            {
                "active": True,
                "login_source": session.get("login_source"),
                "session": session_payload,
            },
        )
    except SessionAuthError as session_error:
        return session_error_response(session_error)
