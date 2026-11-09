import os
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4


MAX_PROFILE_IMAGE_BYTES = 5 * 1024 * 1024
MIN_PROFILE_IMAGE_PIXELS = 256
MAX_PROFILE_IMAGE_PIXELS = 512
PROFILE_IMAGE_CONTENT_TYPE = "image/jpeg"
PROFILE_IMAGE_READ_TTL_SECONDS = 3600
PROFILE_IMAGE_UPLOAD_TTL_SECONDS = 300


def _identity_for_personal_organization(connection, organization_id, username):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT identity.id,
                   identity.profile_image_key,
                   identity.profile_image_version,
                   identity.profile_image_updated_at
            FROM "SkwshOrgUsers" AS membership
            INNER JOIN "SkwshOrgSettings" AS organization
                ON organization.id = membership.organization_id
            INNER JOIN "users" AS identity
                ON identity.id = membership.user_id
            WHERE membership.organization_id = %(organization_id)s
              AND LOWER(BTRIM(membership.clubusername)) = LOWER(BTRIM(%(username)s))
              AND organization.org_type = 'personal'
            LIMIT 1
            """,
            {"organization_id": int(organization_id), "username": username},
        )
        return cursor.fetchone()


def _profile_payload(s3_client, bucket, identity):
    key = (identity or {}).get("profile_image_key")
    version = (identity or {}).get("profile_image_version")
    if not key or not version:
        return {"available": False, "url": None, "version": None, "updated_at": None}

    expires_at = datetime.now(timezone.utc) + timedelta(seconds=PROFILE_IMAGE_READ_TTL_SECONDS)
    url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=PROFILE_IMAGE_READ_TTL_SECONDS,
    )
    return {
        "available": True,
        "url": url,
        "version": str(version),
        "updated_at": identity["profile_image_updated_at"].isoformat() if identity.get("profile_image_updated_at") else None,
        "expires_at": expires_at.isoformat(),
    }


def get_profile_image(connection, s3_client, bucket, organization_id, username):
    identity = _identity_for_personal_organization(connection, organization_id, username)
    if not identity:
        raise ValueError("Personal profile was not found")
    return _profile_payload(s3_client, bucket, identity)


def create_profile_image_upload(connection, s3_client, bucket, organization_id, username):
    identity = _identity_for_personal_organization(connection, organization_id, username)
    if not identity:
        raise ValueError("Personal profile was not found")

    version = uuid4()
    key = f"profile-images/{identity['id']}/{version}.jpg"
    fields = {
        "Content-Type": PROFILE_IMAGE_CONTENT_TYPE,
        "Cache-Control": "private, max-age=3600",
        "x-amz-tagging": "pending=true",
    }
    upload = s3_client.generate_presigned_post(
        Bucket=bucket,
        Key=key,
        Fields=fields,
        Conditions=[
            {"Content-Type": PROFILE_IMAGE_CONTENT_TYPE},
            {"Cache-Control": fields["Cache-Control"]},
            {"x-amz-tagging": fields["x-amz-tagging"]},
            ["content-length-range", 1, MAX_PROFILE_IMAGE_BYTES],
        ],
        ExpiresIn=PROFILE_IMAGE_UPLOAD_TTL_SECONDS,
    )
    return {
        "url": upload["url"],
        "fields": upload["fields"],
        "object_key": key,
        "content_type": PROFILE_IMAGE_CONTENT_TYPE,
        "max_bytes": MAX_PROFILE_IMAGE_BYTES,
        "min_pixels": MIN_PROFILE_IMAGE_PIXELS,
        "max_pixels": MAX_PROFILE_IMAGE_PIXELS,
        "expires_in_seconds": PROFILE_IMAGE_UPLOAD_TTL_SECONDS,
    }


def _jpeg_dimensions_and_metadata(data):
    if len(data) < 4 or data[:2] != b"\xff\xd8" or data[-2:] != b"\xff\xd9":
        raise ValueError("The uploaded file is not a complete JPEG image")

    width = height = None
    has_private_metadata = False
    saw_scan = False
    index = 2
    standalone = {0x01, *range(0xD0, 0xDA)}
    start_of_frame = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
    while index < len(data) - 1:
        if data[index] != 0xFF:
            index += 1
            continue
        while index < len(data) and data[index] == 0xFF:
            index += 1
        if index >= len(data):
            break
        marker = data[index]
        index += 1
        if marker in standalone or marker in {0xD8, 0xD9}:
            continue
        if marker == 0xDA:
            saw_scan = True
            break
        if index + 2 > len(data):
            raise ValueError("The JPEG image is malformed")
        segment_length = int.from_bytes(data[index:index + 2], "big")
        if segment_length < 2 or index + segment_length > len(data):
            raise ValueError("The JPEG image is malformed")
        if marker in {0xE1, 0xED}:
            has_private_metadata = True
        if marker in start_of_frame:
            if segment_length < 7:
                raise ValueError("The JPEG image dimensions are malformed")
            height = int.from_bytes(data[index + 3:index + 5], "big")
            width = int.from_bytes(data[index + 5:index + 7], "big")
        index += segment_length

    if not width or not height or not saw_scan:
        raise ValueError("The JPEG image dimensions could not be read")
    return width, height, has_private_metadata


def complete_profile_image_upload(connection, s3_client, bucket, organization_id, username, object_key):
    identity = _identity_for_personal_organization(connection, organization_id, username)
    if not identity:
        raise ValueError("Personal profile was not found")

    prefix = f"profile-images/{identity['id']}/"
    if not object_key or not str(object_key).startswith(prefix):
        raise ValueError("The uploaded profile image does not belong to this account")
    try:
        version = UUID(str(object_key).removeprefix(prefix).removesuffix(".jpg"))
    except (ValueError, AttributeError):
        raise ValueError("The profile image object key is invalid") from None

    response = s3_client.get_object(Bucket=bucket, Key=object_key)
    content_type = str(response.get("ContentType") or "").split(";", 1)[0].lower()
    data = response["Body"].read(MAX_PROFILE_IMAGE_BYTES + 1)
    if content_type != PROFILE_IMAGE_CONTENT_TYPE:
        raise ValueError("Profile images must be uploaded as JPEG")
    if not data or len(data) > MAX_PROFILE_IMAGE_BYTES:
        raise ValueError("Profile images must be no larger than 5 MB")
    width, height, has_private_metadata = _jpeg_dimensions_and_metadata(data)
    if width != height or not (MIN_PROFILE_IMAGE_PIXELS <= width <= MAX_PROFILE_IMAGE_PIXELS):
        raise ValueError("Profile images must be square and between 256 and 512 pixels")
    if has_private_metadata:
        raise ValueError("Profile images must not contain EXIF or IPTC metadata")

    s3_client.put_object_tagging(
        Bucket=bucket,
        Key=object_key,
        Tagging={"TagSet": [{"Key": "current", "Value": "true"}]},
    )
    previous_key = identity.get("profile_image_key")
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE "users"
                SET profile_image_key = %(object_key)s,
                    profile_image_version = %(version)s,
                    profile_image_updated_at = now(),
                    updated_at = now()
                WHERE id = %(identity_id)s
                RETURNING profile_image_key, profile_image_version, profile_image_updated_at
                """,
                {"object_key": object_key, "version": str(version), "identity_id": identity["id"]},
            )
            updated = cursor.fetchone()
        connection.commit()
    except Exception:
        connection.rollback()
        s3_client.delete_object(Bucket=bucket, Key=object_key)
        raise
    if previous_key and previous_key != object_key:
        try:
            s3_client.delete_object(Bucket=bucket, Key=previous_key)
        except Exception:
            # The accepted image is already authoritative. A failed old-version
            # cleanup is safe to retry operationally and must not fail the save.
            pass
    return _profile_payload(s3_client, bucket, updated)


def delete_profile_image(connection, s3_client, bucket, organization_id, username):
    identity = _identity_for_personal_organization(connection, organization_id, username)
    if not identity:
        raise ValueError("Personal profile was not found")
    object_key = identity.get("profile_image_key")
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE "users"
            SET profile_image_key = NULL,
                profile_image_version = NULL,
                profile_image_updated_at = NULL,
                updated_at = now()
            WHERE id = %(identity_id)s
            """,
            {"identity_id": identity["id"]},
        )
    connection.commit()
    if object_key:
        try:
            s3_client.delete_object(Bucket=bucket, Key=object_key)
        except Exception:
            pass
    return {"deleted": bool(object_key)}


def configured_profile_image_bucket():
    bucket = (os.getenv("PROFILE_IMAGE_BUCKET") or "").strip()
    if not bucket:
        raise RuntimeError("PROFILE_IMAGE_BUCKET is not configured")
    return bucket
