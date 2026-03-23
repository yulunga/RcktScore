from common.root_admin_logic import get_root_admin_dashboard
from common.supabase_client import get_db_connection
from common.utils import success_response


def lambda_handler(event, context):
    with get_db_connection() as connection:
        dashboard = get_root_admin_dashboard(connection)

    return success_response(200, {"rootAdminDashboard": dashboard})
