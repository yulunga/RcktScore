import json

from aws_lambda_powertools import Logger

from common.apple_subscription_lifecycle import AppleLifecycleError, process_notification
from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


logger = Logger(service="apple_subscription_notifications")


def lambda_handler(event, context):
    try:
        body = event.get("body") or "{}"
        payload = body if isinstance(body, dict) else json.loads(body)
        signed_payload = payload.get("signedPayload")
    except (TypeError, json.JSONDecodeError):
        return error_response(400, "APPLE_NOTIFICATION_INVALID", "The request body is not valid JSON.")

    try:
        with get_db_connection() as connection:
            result = process_notification(connection, signed_payload)
    except AppleLifecycleError as error:
        logger.warning(
            "Rejected Apple server notification code=%s retryable=%s",
            error.code,
            error.retryable,
        )
        return error_response(
            error.status_code,
            error.code,
            error.message,
            {"retryable": error.retryable},
        )
    except Exception:
        logger.exception("Apple server notification processing failed")
        return error_response(
            500,
            "APPLE_NOTIFICATION_PROCESSING_FAILED",
            "The notification could not be processed. Apple should retry it.",
            {"retryable": True},
        )

    logger.info(
        "Processed Apple notification uuid=%s duplicate=%s",
        result.get("notification_uuid"),
        result.get("duplicate", False),
    )
    return success_response(200, {"appleNotification": result})
