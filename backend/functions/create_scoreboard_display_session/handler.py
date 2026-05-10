from aws_lambda_powertools import Logger

from common.scoreboard_logic import DisplaySessionError, create_scoreboard_display_session
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


logger = Logger(service="create_scoreboard_display_session")


def lambda_handler(event, context):
    payload = parse_body(event)
    code = payload.get("code")
    if not code:
        return error_response(400, "VALIDATION_ERROR", "code is required")

    try:
        with get_db_connection() as connection:
            session_payload = create_scoreboard_display_session(connection, code)
    except DisplaySessionError as session_error:
        return error_response(
            session_error.status_code,
            session_error.code,
            session_error.message,
            session_error.details,
        )
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    logger.info("Created scoreboard display session")
    return success_response(200, session_payload)
