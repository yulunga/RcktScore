import os

import boto3


def send_email_message(*, destination_email, source_email, subject, text_body, reply_to_addresses=None):
    ses_client = boto3.client("ses", region_name=os.getenv("AWS_REGION"))
    ses_client.send_email(
        Source=source_email,
        Destination={"ToAddresses": [destination_email]},
        ReplyToAddresses=reply_to_addresses or [],
        Message={
            "Subject": {
                "Data": subject,
                "Charset": "UTF-8",
            },
            "Body": {
                "Text": {
                    "Data": text_body,
                    "Charset": "UTF-8",
                }
            },
        },
    )
