from common.root_admin_logic import create_root_admin_organization
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


def lambda_handler(event, context):
    payload = parse_body(event)

    try:
        with get_db_connection() as connection:
            organization = create_root_admin_organization(connection, payload)
    except ValueError as request_error:
        return error_response(400, "INVALID_INPUT", str(request_error))

    return success_response(201, {"organization": organization})
