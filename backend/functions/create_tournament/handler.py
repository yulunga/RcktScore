from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.tournament.access import TournamentAccessError, require_tournament_feature
from common.tournament.tournament_logic import create_tournament
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")
    payload = parse_body(event)

    try:
        with get_db_connection() as connection:
            auth_context = authorize_organization_session(connection, event, organization_id, require_admin=True)
            require_tournament_feature(connection, organization_id)
            tournament = create_tournament(
                connection,
                organization_id,
                payload,
                auth_context["session"]["username"],
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except TournamentAccessError as access_error:
        return error_response(403, "TOURNAMENT_FEATURE_DISABLED", str(access_error))
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    return success_response(201, {"tournament": tournament})

