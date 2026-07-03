from common.root_admin_logic import update_root_admin_platform_sports
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


def lambda_handler(event, context):
    payload = parse_body(event)

    if "enabled_sports" not in payload:
        return error_response(400, "VALIDATION_ERROR", "enabled_sports is required")

    try:
        with get_db_connection() as connection:
            platform_sports = update_root_admin_platform_sports(
                connection,
                payload.get("enabled_sports"),
                updated_by=payload.get("updated_by"),
            )
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    return success_response(200, {"platformSports": platform_sports})
