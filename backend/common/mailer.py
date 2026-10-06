import os
from email.utils import formataddr, parseaddr

import boto3


def send_email_message(
    *,
    destination_email,
    source_email,
    subject,
    text_body,
    html_body=None,
    reply_to_addresses=None,
):
    ses_client = boto3.client("ses", region_name=os.getenv("AWS_REGION"))
    source_name, source_address = parseaddr(source_email)
    formatted_source = source_email if source_name else formataddr(("HitnScore", source_address))
    body = {
        "Text": {
            "Data": text_body,
            "Charset": "UTF-8",
        }
    }
    if html_body:
        body["Html"] = {
            "Data": html_body,
            "Charset": "UTF-8",
        }

    ses_client.send_email(
        Source=formatted_source,
        Destination={"ToAddresses": [destination_email]},
        ReplyToAddresses=reply_to_addresses or [],
        Message={
            "Subject": {
                "Data": subject,
                "Charset": "UTF-8",
            },
            "Body": body,
        },
    )
