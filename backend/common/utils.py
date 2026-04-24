import json
import os


DEFAULT_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,x-api-key,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
}


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": DEFAULT_HEADERS,
        "body": json.dumps(body),
    }


def success_response(status_code, data=None, meta=None):
    return _response(
        status_code,
        {
            "success": True,
            "data": data if data is not None else {},
            "error": None,
            "meta": meta or {},
        },
    )


def error_response(status_code, code, message, details=None):
    error = {
        "code": code,
        "message": message,
    }
    if details is not None:
        error["details"] = details

    return _response(
        status_code,
        {
            "success": False,
            "data": None,
            "error": error,
            "meta": {},
        },
    )


def json_response(status_code, body):
    return _response(status_code, body)


def html_response(status_code, html, headers=None):
    response_headers = {
        "Content-Type": "text/html; charset=utf-8",
    }
    if headers:
        response_headers.update(headers)

    return {
        "statusCode": status_code,
        "headers": response_headers,
        "body": html,
    }


def parse_body(event):
    body = event.get("body")
    if not body:
        return {}
    if isinstance(body, dict):
        return body
    return json.loads(body)


def path_parameter(event, name):
    return (event.get("pathParameters") or {}).get(name)


def require_fields(payload, fields):
    return [field for field in fields if not payload.get(field)]


def request_base_url(event):
    override = (os.getenv("USER_APPROVAL_BASE_URL") or "").strip()
    if override:
        return override.rstrip("/")

    request_context = event.get("requestContext") or {}
    domain_name = request_context.get("domainName")
    stage = request_context.get("stage")

    if not domain_name:
        return ""

    base_url = f"https://{domain_name}"
    if stage and stage != "$default":
        base_url = f"{base_url}/{stage}"

    return base_url
