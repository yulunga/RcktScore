from aws_lambda_powertools import Logger

from common.google_play_subscription_logic import GooglePlayError, get_purchase_context
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_google_play_subscription_context")


def lambda_handler(event, context):
    try:
        organization_id = int(path_parameter(event, "organization_id"))
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "organization_id must be a number")

    try:
        with get_db_connection() as connection:
            authorization = authorize_organization_session(
                connection, event, organization_id, require_admin=False
            )
            purchase_context = get_purchase_context(
                connection, organization_id, authorization["session"]["username"]
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except GooglePlayError as error:
        return error_response(error.status_code, error.code, error.message)

    logger.info("Returned Google Play purchase context organization_id=%s", organization_id)
    return success_response(200, {"googlePlaySubscriptionContext": purchase_context})
