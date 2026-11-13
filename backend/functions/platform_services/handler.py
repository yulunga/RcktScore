from psycopg.types.json import Jsonb

from common.platform_services import normalize_exception_emails
from common.root_admin_session_logic import require_root_admin_session
from common.session_logic import SessionAuthError, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, success_response


def _read_services(connection):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT public_registration_enabled, public_registration_message
            FROM public_registration_settings
            WHERE id = 'default'
            """
        )
        registration = cursor.fetchone() or {}
        cursor.execute(
            """
            SELECT subscriptions_enabled, subscription_exception_emails
            FROM platform_settings
            WHERE id = 'default'
            """
        )
        subscriptions = cursor.fetchone() or {}
    enabled_values = [
        bool(registration.get("public_registration_enabled", True)),
        bool(subscriptions.get("subscriptions_enabled", True)),
    ]
    status = "green" if all(enabled_values) else ("red" if not any(enabled_values) else "orange")
    return {
        "status": status,
        "services": {
            "public_registration": {
                "enabled": enabled_values[0],
                "message": registration.get("public_registration_message") or "",
            },
            "subscriptions": {
                "enabled": enabled_values[1],
                "exceptions": subscriptions.get("subscription_exception_emails") or [],
            },
        },
    }


def _update_services(connection, payload):
    services = payload.get("services") if isinstance(payload, dict) else None
    registration = services.get("public_registration") if isinstance(services, dict) else None
    subscriptions = services.get("subscriptions") if isinstance(services, dict) else None
    if not isinstance(registration, dict) or not isinstance(subscriptions, dict):
        return error_response(400, "INVALID_SERVICES", "Enter valid service settings.")
    registration_enabled = registration.get("enabled")
    registration_message = str(registration.get("message") or "").strip()
    subscriptions_enabled = subscriptions.get("enabled")
    if not isinstance(registration_enabled, bool) or not 1 <= len(registration_message) <= 1000:
        return error_response(400, "INVALID_REGISTRATION_SERVICE", "Enter a registration message between 1 and 1,000 characters.")
    if not isinstance(subscriptions_enabled, bool):
        return error_response(400, "INVALID_SUBSCRIPTION_SERVICE", "Choose whether subscriptions are enabled.")
    exception_emails = normalize_exception_emails(subscriptions.get("exceptions"))
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE public_registration_settings
            SET public_registration_enabled = %s, public_registration_message = %s
            WHERE id = 'default'
            """,
            (registration_enabled, registration_message),
        )
        cursor.execute(
            """
            UPDATE platform_settings
            SET subscriptions_enabled = %s,
                subscription_exception_emails = %s,
                updated_at = now()
            WHERE id = 'default'
            """,
            (subscriptions_enabled, Jsonb(exception_emails)),
        )
    connection.commit()
    return success_response(200, _read_services(connection))


def lambda_handler(event, context):
    try:
        with get_db_connection() as connection:
            require_root_admin_session(connection, event)
            method = event["requestContext"]["http"]["method"]
            if method == "GET":
                return success_response(200, _read_services(connection))
            try:
                payload = parse_body(event)
            except ValueError:
                payload = None
            if not isinstance(payload, dict):
                return error_response(400, "INVALID_REQUEST", "Enter valid service settings.")
            return _update_services(connection, payload)
    except SessionAuthError as error:
        return session_error_response(error)
