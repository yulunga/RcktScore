import pytest

from common.profile_image_logic import (
    MAX_PROFILE_IMAGE_BYTES,
    _jpeg_dimensions_and_metadata,
    create_profile_image_upload,
)


def _jpeg(width=512, height=512, metadata_marker=None):
    segments = [b"\xff\xd8"]
    if metadata_marker:
        segments.append(bytes([0xFF, metadata_marker]) + (4).to_bytes(2, "big") + b"xx")
    sof_payload = bytes([8]) + height.to_bytes(2, "big") + width.to_bytes(2, "big") + bytes([1, 1, 0x11, 0])
    segments.append(b"\xff\xc0" + (len(sof_payload) + 2).to_bytes(2, "big") + sof_payload)
    scan_payload = bytes([1, 1, 0, 0, 63, 0])
    segments.append(b"\xff\xda" + (len(scan_payload) + 2).to_bytes(2, "big") + scan_payload)
    segments.append(b"compressed-pixels\xff\xd9")
    return b"".join(segments)


def test_jpeg_validation_reads_square_dimensions_and_detects_private_metadata():
    assert _jpeg_dimensions_and_metadata(_jpeg()) == (512, 512, False)
    assert _jpeg_dimensions_and_metadata(_jpeg(metadata_marker=0xE1)) == (512, 512, True)


def test_jpeg_validation_rejects_non_jpeg_and_missing_scan():
    with pytest.raises(ValueError):
        _jpeg_dimensions_and_metadata(b"not-an-image")
    with pytest.raises(ValueError):
        _jpeg_dimensions_and_metadata(b"\xff\xd8\xff\xd9")


class _Cursor:
    def __enter__(self): return self
    def __exit__(self, *_args): return False
    def execute(self, _query, _params): pass
    def fetchone(self):
        return {
            "id": "5c4982d0-7e75-4c37-b548-1847bf7bd878",
            "profile_image_key": None,
            "profile_image_version": None,
            "profile_image_updated_at": None,
        }


class _Connection:
    def cursor(self): return _Cursor()


class _S3:
    def __init__(self): self.arguments = None
    def generate_presigned_post(self, **kwargs):
        self.arguments = kwargs
        return {"url": "https://example.invalid/upload", "fields": kwargs["Fields"]}


def test_upload_policy_is_identity_scoped_compressed_jpeg_and_five_megabytes():
    s3 = _S3()
    upload = create_profile_image_upload(_Connection(), s3, "private-images", 50001, "user@example.com")

    assert upload["object_key"].startswith("profile-images/5c4982d0-7e75-4c37-b548-1847bf7bd878/")
    assert upload["content_type"] == "image/jpeg"
    assert upload["max_bytes"] == MAX_PROFILE_IMAGE_BYTES
    assert ["content-length-range", 1, MAX_PROFILE_IMAGE_BYTES] in s3.arguments["Conditions"]
    assert s3.arguments["Fields"]["x-amz-tagging"] == "pending=true"
