from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.tournament.access import TournamentAccessError, require_tournament_feature
from common.tournament.tournament_logic import update_tournament_draw_slot
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    tournament_id = path_parameter(event, "tournament_id")
    match_id = path_parameter(event, "match_id")
    payload = parse_body(event)
    organization_id = payload.get("organization_id")
    if not tournament_id or not match_id or not organization_id:
        return error_response(400, "VALIDATION_ERROR", "tournament_id, match_id and organization_id are required")
    try:
        with get_db_connection() as connection:
            auth_context = authorize_organization_session(connection, event, organization_id, require_admin=True)
            require_tournament_feature(connection, organization_id)
            tournament = update_tournament_draw_slot(
                connection, tournament_id, match_id, organization_id, payload, auth_context["session"]["username"]
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except TournamentAccessError as access_error:
        return error_response(403, "TOURNAMENT_FEATURE_DISABLED", str(access_error))
    except LookupError as request_error:
        return error_response(404, "TOURNAMENT_DRAW_MATCH_NOT_FOUND", str(request_error))
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    return success_response(200, {"tournament": tournament})
