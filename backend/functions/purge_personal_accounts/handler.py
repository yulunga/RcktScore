from aws_lambda_powertools import Logger

from common.organization_logic import purge_due_personal_accounts
from common.supabase_client import get_db_connection


logger = Logger(service="purge_personal_accounts")


def lambda_handler(event, context):
    with get_db_connection() as connection:
        result = purge_due_personal_accounts(connection)
    logger.info("Personal account clearing result=%s", result)
    return result
