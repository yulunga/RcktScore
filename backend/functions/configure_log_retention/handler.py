import json
import os
import urllib.request

import boto3
from botocore.exceptions import ClientError


def _retention_days(event):
    raw_value = (event.get("ResourceProperties") or {}).get("RetentionInDays")
    return int(raw_value or os.getenv("LOG_RETENTION_DAYS", "60"))


def _configured_function_names(event):
    values = (event.get("ResourceProperties") or {}).get("FunctionNames") or []
    return sorted({str(value).strip() for value in values if str(value).strip()})


def _ensure_log_group(client, log_group_name, retention_days):
    try:
        client.create_log_group(logGroupName=log_group_name)
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") != "ResourceAlreadyExistsException":
            raise
    client.put_retention_policy(logGroupName=log_group_name, retentionInDays=retention_days)


def _enforce_named_groups(client, function_names, retention_days):
    for function_name in function_names:
        _ensure_log_group(client, f"/aws/lambda/{function_name}", retention_days)


def _enforce_stack_groups(client, prefix, retention_days):
    paginator = client.get_paginator("describe_log_groups")
    for page in paginator.paginate(logGroupNamePrefix=prefix):
        for group in page.get("logGroups", []):
            group_name = group.get("logGroupName")
            if group_name:
                client.put_retention_policy(logGroupName=group_name, retentionInDays=retention_days)


def _send_cloudformation_response(event, context, status, reason=None):
    response_url = event.get("ResponseURL")
    if not response_url:
        return
    body = json.dumps(
        {
            "Status": status,
            "Reason": reason or f"See CloudWatch log stream {getattr(context, 'log_stream_name', 'unknown')}",
            "PhysicalResourceId": event.get("PhysicalResourceId") or "hitnscore-log-retention",
            "StackId": event.get("StackId"),
            "RequestId": event.get("RequestId"),
            "LogicalResourceId": event.get("LogicalResourceId"),
            "NoEcho": False,
            "Data": {},
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        response_url,
        data=body,
        method="PUT",
        headers={"content-type": "", "content-length": str(len(body))},
    )
    with urllib.request.urlopen(request, timeout=10):
        pass


def lambda_handler(event, context):
    is_cloudformation = bool(event.get("ResponseURL"))
    try:
        if event.get("RequestType") == "Delete":
            _send_cloudformation_response(event, context, "SUCCESS")
            return {"deleted": True}

        client = boto3.client("logs")
        retention_days = _retention_days(event)
        function_names = _configured_function_names(event)
        if function_names:
            _enforce_named_groups(client, function_names, retention_days)
        else:
            stack_name = (os.getenv("STACK_NAME") or "").strip()
            if not stack_name:
                raise ValueError("STACK_NAME is required for scheduled retention enforcement")
            _enforce_stack_groups(client, f"/aws/lambda/{stack_name}-", retention_days)

        _send_cloudformation_response(event, context, "SUCCESS")
        return {"retention_days": retention_days, "configured_group_count": len(function_names)}
    except Exception as error:
        if is_cloudformation:
            _send_cloudformation_response(event, context, "FAILED", str(error))
            return {"error": "LOG_RETENTION_CONFIGURATION_FAILED"}
        raise
