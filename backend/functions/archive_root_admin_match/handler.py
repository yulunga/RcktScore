from common.root_admin_logic import archive_root_admin_match
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    try:
        with get_db_connection() as connection:
            match = archive_root_admin_match(connection, match_id)
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))

    return success_response(200, {"match": match})
