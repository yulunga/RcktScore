from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.tournament.access import TournamentAccessError, require_tournament_feature
from common.tournament.tournament_logic import list_tournaments
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    try:
        with get_db_connection() as connection:
            authorize_organization_session(connection, event, organization_id, require_admin=False)
            require_tournament_feature(connection, organization_id)
            tournaments = list_tournaments(connection, organization_id)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except TournamentAccessError as access_error:
        return error_response(403, "TOURNAMENT_FEATURE_DISABLED", str(access_error))

    return success_response(200, {"tournaments": tournaments})
