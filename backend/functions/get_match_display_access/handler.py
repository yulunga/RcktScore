from aws_lambda_powertools import Logger

from common.session_logic import SessionAuthError, authorize_match_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, path_parameter, success_response


logger = Logger(service="get_match_display_access")


def _fetch_match_display_access(connection, match_id):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                matches.id,
                matches.tenant_id,
                matches.court_id,
                matches.court_name,
                matches.court_alias,
                court.display_code,
                court.display_code_enabled
            FROM matches
            LEFT JOIN "SkwshCourts" AS court
                ON court.id = matches.court_id
            WHERE matches.id = %(match_id)s
            LIMIT 1
            """,
            {"match_id": match_id},
        )
        row = cursor.fetchone()

    if not row:
        return None

    return {
        "match_id": str(row["id"]),
        "tenant_id": row["tenant_id"],
        "court_id": row["court_id"],
        "court_name": row.get("court_name") or "",
        "court_alias": row.get("court_alias") or "",
        "display_code": row.get("display_code") or "",
        "display_code_enabled": bool(row.get("display_code_enabled")),
    }


def lambda_handler(event, context):
    match_id = path_parameter(event, "match_id")
    if not match_id:
        return error_response(400, "VALIDATION_ERROR", "match_id path parameter is required")

    try:
        with get_db_connection() as connection:
            authorize_match_session(connection, event, match_id)
            display_access = _fetch_match_display_access(connection, match_id)
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)

    if not display_access:
        return error_response(404, "MATCH_NOT_FOUND", "Match not found")

    logger.info("Fetched display access for match %s", match_id)
    return success_response(200, {"displayAccess": display_access})
