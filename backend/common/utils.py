import json
import os


DEFAULT_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": os.getenv("WEB_APP_ORIGIN", "https://app.hitnscore.com"),
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers": "Content-Type,x-api-key,Authorization,X-CSRF-Token,X-HitnScore-Session",
    "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
}


def _response(status_code, body, headers=None, cookies=None):
    response_headers = dict(DEFAULT_HEADERS)
    if headers:
        response_headers.update(headers)
    response = {
        "statusCode": status_code,
        "headers": response_headers,
        "body": json.dumps(body),
    }
    if cookies:
        response["cookies"] = list(cookies)
    return response


def success_response(status_code, data=None, meta=None, headers=None, cookies=None):
    return _response(
        status_code,
        {
            "success": True,
            "data": data if data is not None else {},
            "error": None,
            "meta": meta or {},
        },
        headers=headers,
        cookies=cookies,
    )


def error_response(status_code, code, message, details=None, headers=None, cookies=None):
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
        headers=headers,
        cookies=cookies,
    )


def json_response(status_code, body, headers=None, cookies=None):
    return _response(status_code, body, headers=headers, cookies=cookies)


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
