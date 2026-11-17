from aws_lambda_powertools import Logger

from common.google_play_subscription_logic import reconcile_subscriptions
from common.supabase_client import get_db_connection


logger = Logger(service="reconcile_google_play_subscriptions")


def lambda_handler(event, context):
    with get_db_connection() as connection:
        result = reconcile_subscriptions(connection, logger=logger)
    logger.info("Google Play subscription reconciliation result=%s", result)
    if result["failed"]:
        # Surfaces through the Lambda Errors alarm while still applying the successes.
        raise RuntimeError(f"Google Play reconciliation failed for {result['failed']} subscription(s)")
    return result
