import os

from aws_lambda_powertools import Logger

from common.auth_logic import (
    AccountDeletionPending,
    IdentityPasswordResetRequired,
    authenticate_org_user_memberships,
)
from common.logging_utils import mask_email_for_log
from common.password_reset_logic import request_password_reset
from common.session_logic import (
    SessionAuthError,
    create_org_user_session,
    get_active_session_for_username,
    login_source_label,
    normalize_login_source,
    session_cookie_for_result,
    session_error_response,
    validate_web_origin,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="login")


def identity_first_login_enabled():
    return os.environ.get("IDENTITY_FIRST_LOGIN_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}


def default_identity_membership(memberships):
    return next(
        (membership for membership in memberships if membership.get("organization_type") == "personal"),
        memberships[0],
    )


def _password_reset_base_url(event):
    configured = (os.getenv("PASSWORD_RESET_BASE_URL") or "").strip()
    if configured:
        return configured.rstrip("/")
    for key, value in (event.get("headers") or {}).items():
        if key.lower() == "origin" and str(value).strip():
            return str(value).strip().rstrip("/")
    return ""


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["username", "password"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    username = payload["username"].strip()
    masked_username = mask_email_for_log(username)
    password = payload["password"]
    client_type = normalize_login_source(payload.get("client_type"))
    force_logout_other = bool(payload.get("force_logout_other"))

    if client_type == "web_app":
        try:
            validate_web_origin(event)
        except SessionAuthError as session_error:
            return session_error_response(session_error)

    with get_db_connection() as connection:
        try:
            auth_result = authenticate_org_user_memberships(connection, username, password, client_type=client_type)
        except IdentityPasswordResetRequired:
            request_password_reset(
                connection,
                username,
                source_email=(os.getenv("PASSWORD_RESET_FROM_EMAIL") or "").strip(),
                reset_base_url=_password_reset_base_url(event),
            )
            logger.warning("Password reset required for identity with divergent membership credentials")
            return error_response(
                403,
                "PASSWORD_RESET_REQUIRED",
                "For your security, please reset your password. We've emailed you a link.",
            )
        except AccountDeletionPending:
            logger.warning("Deletion-pending login attempt for username=%s", masked_username)
            return error_response(
                403,
                "ACCOUNT_DELETE_PENDING",
                "This account is pending deletion and can no longer be used.",
            )

        memberships = auth_result["approved_memberships"]
        pending_memberships = auth_result["pending_memberships"]

        if not memberships:
            if pending_memberships:
                logger.warning("Pending approval login attempt for username=%s", masked_username)
                return error_response(
                    403,
                    "PENDING_APPROVAL",
                    "Your organisation access is pending email approval. Please check your email and accept the invitation.",
                )
            logger.warning("Invalid login attempt for username=%s", masked_username)
            return error_response(401, "INVALID_CREDENTIALS", "Invalid credentials")

        active_session = get_active_session_for_username(connection, username)
        if active_session and not force_logout_other:
            active_client_type = active_session.get("login_source") or client_type
            client_label = login_source_label(active_client_type)
            logger.info("Blocked duplicate identity login from %s for username=%s", client_type, masked_username)
            return error_response(
                409,
                "ACTIVE_SESSION_EXISTS",
                f"This account is already signed in on the {client_label}. Do you want to sign out that session and continue here?",
                {
                    "client_type": active_client_type,
                    "client_label": client_label,
                    "last_seen_at": active_session.get("last_seen_at").isoformat() if active_session.get("last_seen_at") else None,
                },
            )

        created_session = create_org_user_session(connection, username, login_source=client_type)

    if len(memberships) == 1 or identity_first_login_enabled():
        selected_membership = default_identity_membership(memberships)
        user = {
            **selected_membership,
            "available_memberships": memberships,
            "session_expires_at": created_session["expires_at"].isoformat(),
        }
        if client_type == "web_app":
            user["csrf_token"] = created_session["csrf_token"]
        else:
            user["session_token"] = created_session["token"]
        logger.info(
            "Authenticated identity user id=%s organization_id=%s membership_count=%s identity_first=%s",
            user["id"],
            user["organization_id"],
            len(memberships),
            identity_first_login_enabled(),
        )
        return success_response(
            200,
            {"session": user},
            cookies=[session_cookie_for_result(created_session)] if client_type == "web_app" else None,
        )

    logger.info("Authenticated multi-org user username=%s membership_count=%s", masked_username, len(memberships))
    return success_response(
        200,
        {
            "organizationSelection": {
                "username": username,
                "memberships": memberships,
                "session_expires_at": created_session["expires_at"].isoformat(),
                **(
                    {"csrf_token": created_session["csrf_token"]}
                    if client_type == "web_app"
                    else {"session_token": created_session["token"]}
                ),
            },
        },
        cookies=[session_cookie_for_result(created_session)] if client_type == "web_app" else None,
    )
