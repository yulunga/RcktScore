#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <stack-name> <acm-certificate-arn> [site-domain]"
  echo "Example: $0 hitnscore-weblanding arn:aws:acm:us-east-1:123456789012:certificate/abc www.hitnscore.com"
  exit 1
fi

STACK_NAME="$1"
ACM_CERTIFICATE_ARN="$2"
SITE_DOMAIN_NAME="${3:-www.hitnscore.com}"
AWS_REGION="us-east-1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_FILE="$ROOT_DIR/infrastructure/weblanding-cloudfront.yaml"

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides \
    SiteDomainName="$SITE_DOMAIN_NAME" \
    AcmCertificateArn="$ACM_CERTIFICATE_ARN"

echo
echo "Stack outputs:"
aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
  --output table
