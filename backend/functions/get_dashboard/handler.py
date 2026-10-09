from aws_lambda_powertools import Logger

from common.dashboard_logic import get_dashboard_data
from common.session_logic import (
    SessionAuthError,
    authorize_organization_session,
    session_error_response,
)
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_dashboard")


def _optional_positive_int(value, default):
    if value in {None, ""}:
        return default

    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default

    return max(0, parsed)


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    query_params = event.get("queryStringParameters") or {}
    active_limit = _optional_positive_int(query_params.get("active_limit"), 12)
    recent_limit = _optional_positive_int(query_params.get("recent_limit"), 12)
    analytics_period_days = min(
        _optional_positive_int(query_params.get("analytics_period_days"), 30),
        3650,
    )
    include_extended_analytics = "analytics_period_days" in query_params

    try:
        with get_db_connection() as connection:
            auth_context = authorize_organization_session(connection, event, organization_id, require_admin=False)
            membership = auth_context["membership"]
            dashboard = get_dashboard_data(
                connection,
                organization_id,
                active_limit=active_limit,
                recent_limit=recent_limit,
                analytics_period_days=analytics_period_days,
                actor_first_name=membership.get("first_name"),
                actor_surname=membership.get("surname"),
                include_club_analytics=(
                    membership.get("organization_type") == "club"
                    and membership.get("role") == "admin"
                ),
                include_extended_analytics=include_extended_analytics,
            )
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    logger.info("Fetched dashboard data for organization_id=%s", organization_id)
    return success_response(200, {"dashboard": dashboard})
