from datetime import datetime, timezone

from common.access_control import CAPABILITY_ANALYTICS_READ
from common.analytics_logic import build_analytics_export
from common.dashboard_logic import get_dashboard_data
from common.session_logic import SessionAuthError, authorize_organization_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


def _period_days(event):
    try:
        raw_value = (event.get("queryStringParameters") or {}).get("period_days")
        return min(3650, max(0, int(30 if raw_value in {None, ""} else raw_value)))
    except (TypeError, ValueError):
        return 30


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    period_days = _period_days(event)
    try:
        with get_db_connection() as connection:
            auth = authorize_organization_session(
                connection,
                event,
                organization_id,
                required_capability=CAPABILITY_ANALYTICS_READ,
            )
            membership = auth["membership"]
            is_personal = membership.get("organization_type") == "personal"
            if is_personal and membership.get("plan") != "personal_plus":
                return error_response(403, "ANALYTICS_EXPORT_UPGRADE_REQUIRED", "Analytics export requires Personal Plus")

            dashboard = get_dashboard_data(
                connection,
                organization_id,
                active_limit=0,
                recent_limit=0,
                analytics_period_days=period_days,
                actor_first_name=membership.get("first_name"),
                actor_surname=membership.get("surname"),
                include_club_analytics=not is_personal,
                include_extended_analytics=True,
            )
            report_type = "personal" if is_personal else "club"
            csv_content = build_analytics_export(dashboard, report_type, period_days)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    stamp = datetime.now(timezone.utc).date().isoformat()
    return success_response(200, {
        "export": {
            "report_type": report_type,
            "filename": f"hitnscore-{report_type}-analytics-{stamp}.csv",
            "content_type": "text/csv; charset=utf-8",
            "csv_content": csv_content,
            "contains_personal_details": report_type == "personal",
        }
    })
