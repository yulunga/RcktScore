import json
import os

import boto3
from aws_lambda_powertools import Logger

from common.utils import json_response, parse_body, require_fields


logger = Logger(service="websocket_broadcast")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["connection_ids", "payload"])
    if missing_fields:
        return json_response(400, {"message": "Missing required fields", "fields": missing_fields})

    domain_name = payload.get("domain_name") or os.getenv("WEBSOCKET_DOMAIN_NAME")
    stage = payload.get("stage") or os.getenv("WEBSOCKET_STAGE")
    if not domain_name or not stage:
        return json_response(400, {"message": "domain_name and stage are required"})

    management_api = boto3.client(
        "apigatewaymanagementapi",
        endpoint_url=f"https://{domain_name}/{stage}",
    )

    delivered = []
    failed = []
    message_body = json.dumps(payload["payload"]).encode("utf-8")

    for connection_id in payload["connection_ids"]:
        try:
            management_api.post_to_connection(
                ConnectionId=connection_id,
                Data=message_body,
            )
            delivered.append(connection_id)
        except Exception as exc:
            logger.warning("Failed to deliver websocket message to %s: %s", connection_id, exc)
            failed.append({"connection_id": connection_id, "error": str(exc)})

    return json_response(200, {"delivered": delivered, "failed": failed})
