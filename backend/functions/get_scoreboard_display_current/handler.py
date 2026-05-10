from aws_lambda_powertools import Logger

from common.scoreboard_logic import DisplaySessionError, get_scoreboard_display_current
from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


logger = Logger(service="get_scoreboard_display_current")


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            payload = get_scoreboard_display_current(connection, event)
    except DisplaySessionError as session_error:
        return error_response(
            session_error.status_code,
            session_error.code,
            session_error.message,
            session_error.details,
        )

    logger.info("Fetched scoreboard display current state")
    return success_response(200, payload)
