from aws_lambda_powertools import Logger

from common.apple_subscription_reconciliation import reconcile_subscriptions
from common.supabase_client import get_db_connection


logger = Logger(service="reconcile_apple_subscriptions")


def lambda_handler(event, context):
    with get_db_connection() as connection:
        result = reconcile_subscriptions(connection)
    logger.info("Apple subscription reconciliation result=%s", result)
    return result
