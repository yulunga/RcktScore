# Hit N Score Landing Site Deployment

This runbook deploys `weblanding/` as a standalone static site on AWS using:

- S3 for file storage
- CloudFront for HTTPS delivery
- GoDaddy DNS for `www.hitnscore.com`
- GoDaddy forwarding for `hitnscore.com` -> `https://www.hitnscore.com`

This keeps the landing site separate from the React app in `frontend/`, which can continue to run independently at `app.hitnscore.com`.

## Architecture

- `www.hitnscore.com` -> CloudFront distribution
- CloudFront -> private S3 bucket
- `hitnscore.com` -> GoDaddy 301 forwarding to `https://www.hitnscore.com`
- `app.hitnscore.com` -> existing app deployment

This design avoids mixing `weblanding/` into the existing Amplify app and works with GoDaddy DNS without moving nameservers to Route 53.

## Files Added For This Setup

- [infrastructure/weblanding-cloudfront.yaml](/Users/glennrowe/Development/Projects/RcktScore/infrastructure/weblanding-cloudfront.yaml)
- [scripts/deploy-weblanding-stack.sh](/Users/glennrowe/Development/Projects/RcktScore/scripts/deploy-weblanding-stack.sh)
- [scripts/deploy-weblanding-content.sh](/Users/glennrowe/Development/Projects/RcktScore/scripts/deploy-weblanding-content.sh)

## Prerequisites

- AWS CLI installed and authenticated
- Permission to create S3, CloudFront, and ACM resources
- The `hitnscore.com` domain managed in GoDaddy
- AWS resources created in `us-east-1` for the certificate and stack deployment

## Step 1: Create the ACM Certificate

CloudFront requires the certificate to exist in `us-east-1`.

Request a certificate for:

- `www.hitnscore.com`

Optional future-proofing:

- `hitnscore.com`

Example command:

```bash
aws acm request-certificate \
  --region us-east-1 \
  --domain-name www.hitnscore.com \
  --subject-alternative-names hitnscore.com \
  --validation-method DNS
```

Then fetch the validation records:

```bash
aws acm describe-certificate \
  --region us-east-1 \
  --certificate-arn <certificate-arn>
```

In GoDaddy DNS, add the ACM validation `CNAME` records exactly as returned by ACM. Wait until the certificate status becomes `ISSUED`.

## Step 2: Deploy the AWS Stack

Create the isolated S3 bucket and CloudFront distribution:

```bash
./scripts/deploy-weblanding-stack.sh <stack-name> <certificate-arn> www.hitnscore.com
```

Example:

```bash
./scripts/deploy-weblanding-stack.sh \
  hitnscore-weblanding \
  arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555 \
  www.hitnscore.com
```

The script prints these important outputs:

- `BucketName`
- `CloudFrontDistributionId`
- `CloudFrontDomainName`

Keep those values for the next steps.

## Step 3: Upload the Landing Site Content

Deploy the files from `weblanding/` to S3 and invalidate CloudFront:

```bash
./scripts/deploy-weblanding-content.sh <bucket-name> <distribution-id>
```

Example:

```bash
./scripts/deploy-weblanding-content.sh \
  hitnscore-weblanding-landingsitebucket-abc123 \
  E1234567890ABC
```

The script:

- syncs the `weblanding/` folder to S3
- uses short cache headers for `*.html`
- uses longer cache headers for non-HTML files
- invalidates CloudFront so the latest version is served

## Step 4: Configure GoDaddy DNS

In GoDaddy, create a DNS record:

- Type: `CNAME`
- Name: `www`
- Value: the `CloudFrontDomainName` output from the stack

Example value:

```text
d111111abcdef8.cloudfront.net
```

Do not include `https://`.

## Step 5: Configure GoDaddy Root Forwarding

Because GoDaddy standard DNS does not give you a Route 53-style alias record for the root domain, configure domain forwarding:

- Forward `hitnscore.com`
- Destination: `https://www.hitnscore.com`
- Type: `Permanent (301)`
- Settings: `Forward only`

This gives you:

- `www.hitnscore.com` served from CloudFront
- `hitnscore.com` redirecting to the canonical `www` hostname

## Step 6: Verify

Check DNS:

```bash
dig www.hitnscore.com
```

Check the site:

```bash
curl -I https://www.hitnscore.com
curl -I https://hitnscore.com
```

Expected result:

- `https://www.hitnscore.com` returns `200`
- `https://hitnscore.com` returns a redirect to `https://www.hitnscore.com`

## Ongoing Updates

When the landing page changes, only redeploy the content:

```bash
./scripts/deploy-weblanding-content.sh <bucket-name> <distribution-id>
```

Changes to `frontend/` do not affect this site.

## Separation Rules

To keep this clean over time:

- Keep all landing-page content inside `weblanding/`
- Do not import assets from `frontend/`
- Do not add landing-page deployment steps to `infrastructure/amplify.yaml`
- Treat `weblanding/` as its own deployable unit

## Future Improvement Option

If you later move DNS to Route 53 or another provider with apex alias support, you can place both:

- `hitnscore.com`
- `www.hitnscore.com`

directly on CloudFront without using GoDaddy forwarding.
