#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <bucket-name> <cloudfront-distribution-id>"
  echo "Example: $0 hitnscore-weblanding-landingbucket-abc123 E1234567890"
  exit 1
fi

BUCKET_NAME="$1"
DISTRIBUTION_ID="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/weblanding"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Source directory not found: $SOURCE_DIR"
  exit 1
fi

aws s3 sync "$SOURCE_DIR/" "s3://$BUCKET_NAME/" \
  --delete \
  --exclude "*" \
  --include "*.png" \
  --include "*.jpg" \
  --include "*.jpeg" \
  --include "*.svg" \
  --include "*.webp" \
  --include "*.gif" \
  --include "*.avif" \
  --include "*.woff" \
  --include "*.woff2" \
  --cache-control "public,max-age=31536000,immutable"

aws s3 sync "$SOURCE_DIR/" "s3://$BUCKET_NAME/" \
  --delete \
  --exclude "*" \
  --include "*.css" \
  --include "*.js" \
  --include "*.ico" \
  --include "*.json" \
  --include "*.txt" \
  --include "*.xml" \
  --cache-control "public,max-age=300,must-revalidate"

aws s3 sync "$SOURCE_DIR/" "s3://$BUCKET_NAME/" \
  --delete \
  --exclude "*" \
  --include "*.html" \
  --cache-control "public,max-age=60,must-revalidate"

aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*" \
  >/dev/null

echo "Deployed weblanding content to s3://$BUCKET_NAME/"
echo "Created CloudFront invalidation for distribution $DISTRIBUTION_ID"
