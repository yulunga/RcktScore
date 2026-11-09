import boto3

from common.profile_image_logic import (
    complete_profile_image_upload,
    configured_profile_image_bucket,
    create_profile_image_upload,
    delete_profile_image,
    get_profile_image,
)
from common.session_logic import SessionAuthError, authorize_personal_profile_session, session_error_response
from common.supabase_client import get_db_connection
from common.utils import error_response, parse_body, path_parameter, success_response


s3_client = boto3.client("s3")


def _method(event):
    return str((event.get("requestContext") or {}).get("http", {}).get("method") or event.get("httpMethod") or "GET").upper()


def lambda_handler(event, context):
    organization_id = path_parameter(event, "organization_id")
    if not organization_id:
        return error_response(400, "VALIDATION_ERROR", "organization_id path parameter is required")

    method = _method(event)
    route_key = str((event.get("requestContext") or {}).get("routeKey") or "")
    payload = parse_body(event)
    try:
        bucket = configured_profile_image_bucket()
        with get_db_connection() as connection:
            auth = authorize_personal_profile_session(connection, event, organization_id)
            if auth["membership"].get("organization_type") != "personal":
                return error_response(403, "PERSONAL_ACCOUNT_REQUIRED", "Profile images belong to the Personal account")
            username = auth["session"]["username"]
            if method == "GET":
                image = get_profile_image(connection, s3_client, bucket, organization_id, username)
                return success_response(200, {"profile_image": image})
            if method == "DELETE":
                result = delete_profile_image(connection, s3_client, bucket, organization_id, username)
                return success_response(200, result)
            if route_key.endswith("/upload"):
                upload = create_profile_image_upload(connection, s3_client, bucket, organization_id, username)
                return success_response(201, {"upload": upload})
            if route_key.endswith("/complete"):
                image = complete_profile_image_upload(
                    connection, s3_client, bucket, organization_id, username, payload.get("object_key")
                )
                return success_response(200, {"profile_image": image})
            return error_response(405, "METHOD_NOT_ALLOWED", "Unsupported profile image operation")
    except SessionAuthError as auth_error:
        return session_error_response(auth_error)
    except ValueError as validation_error:
        return error_response(400, "INVALID_PROFILE_IMAGE", str(validation_error))
    except RuntimeError as configuration_error:
        return error_response(503, "PROFILE_IMAGE_SERVICE_UNAVAILABLE", str(configuration_error))
