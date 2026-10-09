from common.supabase_client import get_db_connection
from common.tournament.tournament_logic import get_public_tournament_draw
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    access_key = path_parameter(event, "access_key")
    if not access_key:
        return error_response(400, "VALIDATION_ERROR", "access_key is required")
    with get_db_connection() as connection:
        tournament = get_public_tournament_draw(connection, access_key)
    if not tournament:
        return error_response(404, "PUBLIC_DRAW_NOT_FOUND", "Published tournament draw not found")
    return success_response(200, {"tournament": tournament})
