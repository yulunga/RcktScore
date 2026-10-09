from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.tournament.access import TournamentAccessError, require_tournament_feature
from common.tournament.tournament_logic import record_tournament_match_result
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
            auth_context = authorize_organization_session(connection, event, organization_id, require_admin=False)
            require_tournament_feature(connection, organization_id)
            membership = auth_context["membership"]
            tournament = record_tournament_match_result(
                connection,
                tournament_id,
                match_id,
                organization_id,
                payload,
                auth_context["session"]["username"],
                is_admin=membership.get("role") == "admin",
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except TournamentAccessError as access_error:
        return error_response(403, "TOURNAMENT_FEATURE_DISABLED", str(access_error))
    except PermissionError as request_error:
        return error_response(403, "TOURNAMENT_ADMIN_REQUIRED", str(request_error))
    except LookupError as request_error:
        return error_response(404, "TOURNAMENT_MATCH_NOT_FOUND", str(request_error))
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    return success_response(200, {"tournament": tournament})
