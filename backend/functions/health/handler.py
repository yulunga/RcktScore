import time

from aws_lambda_powertools import Logger

from common.supabase_client import get_db_connection
from common.utils import error_response, success_response


logger = Logger(service="health")
SCHEDULE_SOURCE = "rcktscore.health-schedule"


def _database_is_ready():
    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 AS ready")
            row = cursor.fetchone()
    return bool(row and row.get("ready") == 1)


def lambda_handler(event, context):
    started_at = time.monotonic()
    scheduled_check = (event or {}).get("source") == SCHEDULE_SOURCE

    try:
        if not _database_is_ready():
            raise RuntimeError("Database readiness query returned an unexpected result.")
    except Exception as error:
        logger.exception("Production health check failed")
        if scheduled_check:
            # Scheduled failures must raise so the Lambda Errors alarm receives a metric.
            raise RuntimeError("Scheduled production health check failed.") from error
        return error_response(
            503,
            "SERVICE_UNAVAILABLE",
            "The service is not ready to accept requests.",
        )

    duration_ms = round((time.monotonic() - started_at) * 1000)
    logger.info("Production health check passed duration_ms=%s", duration_ms)
    return success_response(
        200,
        {
            "service": "rcktscore-backend",
            "status": "healthy",
            "checks": {"database": "healthy"},
        },
        {"durationMs": duration_ms},
    )
