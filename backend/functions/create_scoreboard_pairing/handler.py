from aws_lambda_powertools import Logger

from common.scoreboard_logic import DisplaySessionError, create_scoreboard_pairing_request
from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


logger = Logger(service="create_scoreboard_pairing")


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            pairing = create_scoreboard_pairing_request(connection, event)
    except DisplaySessionError as pairing_error:
        return error_response(pairing_error.status_code, pairing_error.code, pairing_error.message, pairing_error.details)

    logger.info("Created short-lived scoreboard QR pairing request")
    return success_response(201, {"pairing": pairing})
