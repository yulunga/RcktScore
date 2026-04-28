from aws_lambda_powertools import Logger

from common.auth_logic import authenticate_org_user_memberships
from common.session_logic import (
    create_org_user_session,
    get_active_session_for_username,
    login_source_label,
    normalize_login_source,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="login")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["username", "password"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    username = payload["username"].strip()
    password = payload["password"]
    client_type = normalize_login_source(payload.get("client_type"))
    force_logout_other = bool(payload.get("force_logout_other"))

    with get_db_connection() as connection:
        auth_result = authenticate_org_user_memberships(connection, username, password)

        memberships = auth_result["approved_memberships"]
        pending_memberships = auth_result["pending_memberships"]

        if not memberships:
            if pending_memberships:
                logger.warning("Pending approval login attempt for username=%s", username)
                return error_response(
                    403,
                    "PENDING_APPROVAL",
                    "Your organisation access is pending email approval. Please check your email and accept the invitation.",
                )
            logger.warning("Invalid login attempt for username=%s", username)
            return error_response(401, "INVALID_CREDENTIALS", "Invalid credentials")

        active_session = get_active_session_for_username(connection, username, client_type)
        if active_session and not force_logout_other:
            client_label = login_source_label(client_type)
            logger.info("Blocked duplicate %s login for username=%s", client_type, username)
            return error_response(
                409,
                "ACTIVE_SESSION_EXISTS",
                f"This account is already signed in on the {client_label}. Do you want to sign out there and continue here?",
                {
                    "client_type": client_type,
                    "client_label": client_label,
                    "last_seen_at": active_session.get("last_seen_at").isoformat() if active_session.get("last_seen_at") else None,
                },
            )

        session_token = create_org_user_session(connection, username, login_source=client_type)

    if len(memberships) == 1:
        user = {
            **memberships[0],
            "session_token": session_token,
        }
        logger.info("Authenticated org user id=%s organization_id=%s", user["id"], user["organization_id"])
        return success_response(200, {"session": user})

    logger.info("Authenticated multi-org user username=%s membership_count=%s", username, len(memberships))
    return success_response(
        200,
        {
            "organizationSelection": {
                "username": username,
                "memberships": memberships,
                "session_token": session_token,
            },
        },
    )
