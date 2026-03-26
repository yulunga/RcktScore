import os
import re

import boto3
from aws_lambda_powertools import Logger

from common.utils import error_response, parse_body, require_fields, success_response


logger = Logger(service="send_feedback")

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
ALLOWED_CATEGORIES = {
    "Bug / Something not working",
    "Feature Request",
    "General Feedback",
    "UI / Design Suggestion",
    "Performance Issue",
    "Other",
}


def lambda_handler(event, context):
    payload = parse_body(event)
    missing_fields = require_fields(payload, ["name", "email", "category", "message"])
    if missing_fields:
        return error_response(400, "VALIDATION_ERROR", "Missing required fields", {"fields": missing_fields})

    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    category = (payload.get("category") or "").strip()
    message = (payload.get("message") or "").strip()

    if not EMAIL_PATTERN.match(email):
        return error_response(400, "INVALID_EMAIL", "A valid email address is required")

    if category not in ALLOWED_CATEGORIES:
        return error_response(400, "INVALID_CATEGORY", "A valid feedback category is required")

    if len(message) < 5:
        return error_response(400, "INVALID_MESSAGE", "Please provide more detail")

    destination_email = (
        os.getenv("FEEDBACK_TO_EMAIL")
        or os.getenv("INTEREST_TO_EMAIL")
        or "rcktinterest@ucingo.com"
    )
    source_email = (
        os.getenv("FEEDBACK_FROM_EMAIL")
        or os.getenv("INTEREST_FROM_EMAIL")
        or destination_email
    )

    ses_client = boto3.client("ses", region_name=os.getenv("AWS_REGION"))
    user_agent = (
        payload.get("user_agent")
        or (event.get("headers") or {}).get("user-agent")
        or "Unknown"
    )

    message_text = "\n".join(
        [
            "A new RcktScore feedback submission has been received.",
            "",
            f"Category: {category}",
            f"Name: {name}",
            f"Email: {email}",
            f"Username: {(payload.get('username') or '').strip() or 'Unknown'}",
            f"Organisation: {(payload.get('organization_name') or '').strip() or 'Unknown'}",
            f"Version: {(payload.get('version') or '').strip() or 'Unknown'}",
            f"Build: {(payload.get('build') or '').strip() or 'Unknown'}",
            f"Page URL: {(payload.get('page_url') or '').strip() or 'Unknown'}",
            f"User Agent: {user_agent}",
            "",
            "Message:",
            message,
        ]
    )

    ses_client.send_email(
        Source=source_email,
        Destination={"ToAddresses": [destination_email]},
        ReplyToAddresses=[email],
        Message={
            "Subject": {
                "Data": f"RcktScore: {category}",
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

    logger.info("Feedback accepted for username=%s category=%s", payload.get("username"), category)
    return success_response(202, {"accepted": True})
