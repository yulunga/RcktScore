from aws_lambda_powertools import Logger

from common.google_play_subscription_logic import GooglePlayError, verify_purchase
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="verify_google_play_subscription")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["organization_id", "purchase_token"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})
    try:
        organization_id = int(payload["organization_id"])
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "organization_id must be a number")

    try:
        with get_db_connection() as connection:
            authorization = authorize_organization_session(
                connection, event, organization_id, require_admin=False
            )
            subscription = verify_purchase(
                connection,
                organization_id,
                authorization["session"]["username"],
                payload["purchase_token"],
                request_id=getattr(context, "aws_request_id", None),
                logger=logger,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except GooglePlayError as error:
        logger.warning(
            "Rejected Google Play purchase organization_id=%s code=%s retryable=%s",
            organization_id,
            error.code,
            error.retryable,
        )
        return error_response(error.status_code, error.code, error.message, {"retryable": error.retryable})

    logger.info(
        "Accepted Google Play purchase organization_id=%s status=%s",
        organization_id,
        subscription["status"],
    )
    return success_response(200, {"googlePlaySubscription": subscription})
