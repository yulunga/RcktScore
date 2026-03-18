import os
import re

import boto3
from aws_lambda_powertools import Logger

from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="register_interest")

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["email"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    email = (payload.get("email") or "").strip().lower()
    honeypot = (payload.get("company") or "").strip()

    if not EMAIL_PATTERN.match(email):
        return error_response(400, "INVALID_EMAIL", "A valid email address is required")

    # Quietly absorb obvious bot submissions without sending an email.
    if honeypot:
        logger.warning("Interest honeypot triggered for email=%s", email)
        return success_response(202, {"accepted": True})

    destination_email = os.getenv("INTEREST_TO_EMAIL", "rcktinterest@ucingo.com")
    source_email = os.getenv("INTEREST_FROM_EMAIL", destination_email)
    page_url = (payload.get("page_url") or "").strip()
    user_agent = (
        payload.get("user_agent")
        or (event.get("headers") or {}).get("user-agent")
        or "Unknown"
    )

    ses_client = boto3.client("ses", region_name=os.getenv("AWS_REGION"))
    message_text = "\n".join(
        [
            "A new user has registered interest in RcktScore access.",
            "",
            f"Email: {email}",
            f"Page URL: {page_url or 'Unknown'}",
            f"User Agent: {user_agent}",
        ]
    )

    ses_client.send_email(
        Source=source_email,
        Destination={"ToAddresses": [destination_email]},
        ReplyToAddresses=[email],
        Message={
            "Subject": {
                "Data": "New RcktScore register interest request",
                "Charset": "UTF-8",
            },
            "Body": {
                "Text": {
                    "Data": message_text,
                    "Charset": "UTF-8",
                }
            },
        },
    )

    logger.info("Interest request accepted for email=%s", email)
    return success_response(202, {"accepted": True})
