from aws_lambda_powertools import Logger

from common.scoreboard_logic import DisplaySessionError, exchange_scoreboard_pairing
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


logger = Logger(service="exchange_scoreboard_pairing")


def lambda_handler(event, context):
    token = parse_body(event).get("token")
    if not token:
        return error_response(400, "VALIDATION_ERROR", "token is required")
    try:
        with get_db_connection() as connection:
            payload = exchange_scoreboard_pairing(connection, token)
    except DisplaySessionError as pairing_error:
        return error_response(pairing_error.status_code, pairing_error.code, pairing_error.message, pairing_error.details)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    if payload.get("state") == "approved":
        logger.info("Exchanged scoreboard QR pairing for a display session")
    return success_response(200, payload)
