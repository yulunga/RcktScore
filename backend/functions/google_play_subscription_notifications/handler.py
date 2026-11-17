from aws_lambda_powertools import Logger

from common.google_play_subscription_logic import (
    GooglePlayError,
    decode_push_message,
    process_notification,
    verify_push_authorization,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


logger = Logger(service="google_play_subscription_notifications")


def lambda_handler(event, context):
    headers = {key.lower(): value for key, value in (event.get("headers") or {}).items()}
    try:
        verify_push_authorization(headers.get("authorization"))
        message_id, notification = decode_push_message(event.get("body"))
        with get_db_connection() as connection:
            result = process_notification(connection, message_id, notification)
    except GooglePlayError as error:
        logger.warning("Google Play notification rejected code=%s retryable=%s", error.code, error.retryable)
        # Non-2xx makes Pub/Sub redeliver; only worth it when a retry can succeed.
        status_code = error.status_code if error.retryable or error.status_code in {401, 503} else 200
        return error_response(status_code, error.code, error.message, {"retryable": error.retryable})
    except Exception:
        logger.exception("Google Play notification processing failed")
        return error_response(500, "GOOGLE_PLAY_NOTIFICATION_FAILED", "Processing failed; Pub/Sub will retry.")

    logger.info("Processed Google Play notification message_id=%s", message_id)
    return success_response(200, {"googlePlayNotification": {"message_id": message_id, "duplicate": result.get("duplicate", False)}})
