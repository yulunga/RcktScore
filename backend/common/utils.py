import json


DEFAULT_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,x-api-key",
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
