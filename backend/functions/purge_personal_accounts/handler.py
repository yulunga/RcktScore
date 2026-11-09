import boto3
from aws_lambda_powertools import Logger

from common.organization_logic import purge_due_personal_accounts
from common.profile_image_logic import configured_profile_image_bucket
from common.supabase_client import get_db_connection


logger = Logger(service="purge_personal_accounts")
s3_client = boto3.client("s3")


def lambda_handler(event, context):
    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                '''
                SELECT identity.profile_image_key
                FROM "SkwshOrgSettings" AS organization
                INNER JOIN "users" AS identity
                    ON identity.email_normalized = LOWER(BTRIM(organization.owner_username))
                WHERE organization.org_type = 'personal'
                  AND organization.deletion_requested_at IS NOT NULL
                  AND organization.deletion_purge_after <= now()
                  AND identity.profile_image_key IS NOT NULL
                '''
            )
            image_keys = [row["profile_image_key"] for row in cursor.fetchall()]
        result = purge_due_personal_accounts(connection)
    bucket = configured_profile_image_bucket()
    for image_key in image_keys:
        try:
            s3_client.delete_object(Bucket=bucket, Key=image_key)
        except Exception:
            logger.exception("Unable to remove retained profile image key=%s", image_key)
    logger.info("Personal account clearing result=%s", result)
    return result
