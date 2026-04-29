import os

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
        Source=source_email,
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
