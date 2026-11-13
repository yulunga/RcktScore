from aws_lambda_powertools import Logger

from common.access_control import CAPABILITY_MATCH_READ
from common.match_logic import get_match, websocket_payload
from common.session_logic import (
    SessionAuthError,
    attach_match_scoring_access,
    authorize_match_session,
    session_error_response,
    take_over_match_scoring,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="take_over_match_scoring")


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    try:
        with get_db_connection() as connection:
            auth_context = authorize_match_session(
                connection,
                event,
                match_id,
                required_capability=CAPABILITY_MATCH_READ,
            )
            take_over_match_scoring(connection, match_id, auth_context)
            match = attach_match_scoring_access(get_match(connection, match_id), auth_context)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    logger.info("Club administrator took over scoring for match %s", match_id)
    return success_response(200, {"match": match, "broadcast": websocket_payload(match)})
