from aws_lambda_powertools import Logger

from common.apple_purchase_verification import (
    ApplePurchaseVerificationError,
    verify_and_apply_purchase,
)
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="verify_apple_subscription")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(
        payload,
        ["organization_id", "signed_transaction", "signed_app_transaction"],
    )
    if missing_fields:
        return error_response(
            400,
            "VALIDATION_ERROR",
            "Missing required fields",
            {"fields": missing_fields},
        )

    try:
        organization_id = int(payload["organization_id"])
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "organization_id must be a number")

    request_id = getattr(context, "aws_request_id", None)
    try:
        with get_db_connection() as connection:
            authorization = authorize_organization_session(
                connection,
                event,
                organization_id,
                require_admin=False,
            )
            subscription = verify_and_apply_purchase(
                connection,
                organization_id,
                authorization["session"]["username"],
                payload["signed_transaction"],
                payload["signed_app_transaction"],
                request_id=request_id,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ApplePurchaseVerificationError as verification_error:
        logger.warning(
            "Rejected Apple purchase organization_id=%s code=%s retryable=%s",
            organization_id,
            verification_error.code,
            verification_error.retryable,
        )
        return error_response(
            verification_error.status_code,
            verification_error.code,
            verification_error.message,
            {"retryable": verification_error.retryable},
        )

    logger.info(
        "Accepted verified Apple purchase organization_id=%s transaction_id=%s",
        organization_id,
        subscription["transaction_id"],
    )
    return success_response(200, {"appleSubscription": subscription})
