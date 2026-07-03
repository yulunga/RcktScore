from common.root_admin_logic import get_root_admin_platform_sports
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    with get_db_connection() as connection:
        platform_sports = get_root_admin_platform_sports(connection)

    return success_response(200, {"platformSports": platform_sports})
