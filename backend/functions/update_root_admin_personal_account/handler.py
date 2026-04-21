from common.root_admin_logic import update_root_admin_personal_account_plan
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


def lambda_handler(event, context):
    payload = parse_body(event)
    request_id = path_parameter(event, "request_id")

    if not request_id:
        return error_response(400, "VALIDATION_ERROR", "Personal account ID is required")

    try:
        numeric_request_id = int(request_id)
    except (TypeError, ValueError):
        return error_response(400, "VALIDATION_ERROR", "Personal account ID must be a number")

    try:
        with get_db_connection() as connection:
            personal_account = update_root_admin_personal_account_plan(
                connection,
                numeric_request_id,
                payload.get("personal_plan"),
                updated_by=payload.get("updated_by"),
            )
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))
    except LookupError as request_error:
        return error_response(404, "NOT_FOUND", str(request_error))

    return success_response(200, {"personalAccount": personal_account})
