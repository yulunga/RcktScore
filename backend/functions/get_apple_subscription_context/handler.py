from aws_lambda_powertools import Logger

from common.apple_subscription_logic import (
    AppleSubscriptionError,
    get_or_create_purchase_context,
)
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_apple_subscription_context")


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(
            400,
            "VALIDATION_ERROR",
            "organization_id path parameter is required",
        )

    try:
        parsed_organization_id = int(organization_id)
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "organization_id must be a number")

    try:
        with get_db_connection() as connection:
            authorization = authorize_organization_session(
                connection,
                event,
                parsed_organization_id,
                require_admin=False,
            )
            purchase_context = get_or_create_purchase_context(
                connection,
                parsed_organization_id,
                authorization["session"]["username"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except AppleSubscriptionError as subscription_error:
        return error_response(403, "APPLE_PURCHASE_NOT_ALLOWED", str(subscription_error))

    logger.info(
        "Returned Apple purchase context for organization_id=%s",
        parsed_organization_id,
    )
    return success_response(200, {"appleSubscriptionContext": purchase_context})

