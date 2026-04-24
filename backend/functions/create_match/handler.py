from aws_lambda_powertools import Logger

from common.match_logic import create_match, is_personal_tenant, websocket_payload
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="create_match")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(
        payload,
        ["tenant_id", "player1_name", "player2_name"],
    )
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    try:
        with get_db_connection() as connection:
            authorize_organization_session(connection, event, payload["tenant_id"], require_admin=False)
            if not is_personal_tenant(connection, payload["tenant_id"]):
                missing_court_fields = require_fields(payload, ["court_id", "court_name"])
                if missing_court_fields:
                    return error_response(
                        400,
                        "VALIDATION_ERROR",
                        "Missing required fields",
                        {"fields": missing_court_fields},
                    )

            try:
                match = create_match(connection, payload, source="lambda")
            except ValueError as exc:
                return error_response(400, "INVALID_INPUT", str(exc))
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    logger.info("Created match %s", match["id"])
    return success_response(201, {"match": match, "broadcast": websocket_payload(match)})
