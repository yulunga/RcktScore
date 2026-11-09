ALTER TABLE "users"
    ADD COLUMN IF NOT EXISTS profile_image_key text,
    ADD COLUMN IF NOT EXISTS profile_image_version uuid,
    ADD COLUMN IF NOT EXISTS profile_image_updated_at timestamptz;

COMMENT ON COLUMN "users".profile_image_key IS
    'Private S3 object key for the identity-level profile photograph shared by every client and membership.';
COMMENT ON COLUMN "users".profile_image_version IS
    'Immutable profile-image version used by clients to invalidate cached photographs.';
COMMENT ON COLUMN "users".profile_image_updated_at IS
    'Time the current central profile image was accepted after server-side validation.';
