# AWS Deployment Guide

This document provides complete instructions for deploying the KDLServices website to AWS.

## Prerequisites

1. **AWS Account**: Account ID `876169277867`
2. **AWS CLI**: Install from https://aws.amazon.com/cli/
3. **AWS Credentials**: Access key and secret key with sufficient permissions
4. **jq**: JSON processor (for setup script)
   - Mac: `brew install jq`
   - Linux: `apt-get install jq` or `yum install jq`

## Required AWS Permissions

Your IAM user/role needs the following permissions:
- S3: CreateBucket, PutBucketPolicy, PutBucketWebsite, PutPublicAccessBlock
- CloudFront: CreateDistribution, CreateCloudFrontOriginAccessIdentity
- STS: GetCallerIdentity (for verification)

## One-Time Setup

### Step 1: Configure AWS CLI

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-west-1`
- Default output format: `json`

### Step 2: Run Infrastructure Setup Script

This script creates all necessary AWS resources:

```bash
cd /home/user/644bmholloway06.github.io
./scripts/setup-aws-infrastructure.sh
```

The script will create:
- **S3 Bucket**: `kdlservices-website-876169277867`
- **CloudFront Distribution**: With HTTPS support
- **Origin Access Identity (OAI)**: For secure S3 access
- **Bucket Policy**: Allowing CloudFront to access S3

**Important**: Note the CloudFront Distribution ID from the output - you'll need it in Step 3.

### Step 3: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Go to your repository: https://github.com/644bmholloway06/644bmholloway06.github.io
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Add these secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | Used to authenticate with AWS |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | Used to authenticate with AWS |
| `CLOUDFRONT_DISTRIBUTION_ID` | Distribution ID from Step 2 | Used to invalidate cache after deployment |

**Security Note**: Consider creating a dedicated IAM user with limited permissions for GitHub Actions:

```bash
# Create IAM user for GitHub Actions
aws iam create-user --user-name github-actions-kdlservices

# Attach policy (create a custom policy with minimal permissions)
aws iam attach-user-policy \
  --user-name github-actions-kdlservices \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-user-policy \
  --user-name github-actions-kdlservices \
  --policy-arn arn:aws:iam::aws:policy/CloudFrontFullAccess

# Create access key
aws iam create-access-key --user-name github-actions-kdlservices
```

## Deployment

### Automatic Deployment (Recommended)

Once configured, the website automatically deploys when you push to the `main` branch:

```bash
git add .
git commit -m "Update website"
git push origin main
```

GitHub Actions will:
1. Check out your code
2. Configure AWS credentials
3. Sync files to S3
4. Invalidate CloudFront cache

Monitor the deployment in the **Actions** tab of your GitHub repository.

### Manual Deployment

You can also trigger deployment manually:

1. Go to **Actions** tab in GitHub
2. Select **Deploy to AWS** workflow
3. Click **Run workflow**
4. Select branch and click **Run workflow**

### Local Deployment (For Testing)

```bash
# Sync to S3
aws s3 sync . s3://kdlservices-website-876169277867/ \
  --exclude ".git/*" \
  --exclude ".github/*" \
  --exclude "README.md" \
  --exclude "scripts/*" \
  --delete \
  --region us-west-1

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

## Accessing Your Website

After deployment completes:

1. **Via CloudFront** (Recommended - with HTTPS):
   - URL: `https://YOUR_DISTRIBUTION_DOMAIN.cloudfront.net`
   - Get domain: `aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='KDLServices Website Distribution'].DomainName" --output text`

2. **Via S3** (HTTP only, not recommended for production):
   - URL: `http://kdlservices-website-876169277867.s3-website-us-west-1.amazonaws.com`

**Note**: CloudFront distributions take 10-15 minutes to fully deploy initially.

## Custom Domain Setup (Optional)

To use a custom domain like `kdlservices.com`:

### Step 1: Request SSL Certificate

```bash
# IMPORTANT: Certificate must be in us-east-1 for CloudFront
aws acm request-certificate \
  --domain-name kdlservices.com \
  --validation-method DNS \
  --region us-east-1
```

### Step 2: Validate Certificate

Follow the instructions from ACM to add DNS records for validation.

### Step 3: Update CloudFront Distribution

```bash
aws cloudfront get-distribution-config \
  --id YOUR_DISTRIBUTION_ID > /tmp/cf-config.json

# Edit the config to add:
# - Aliases: ["kdlservices.com", "www.kdlservices.com"]
# - ViewerCertificate.ACMCertificateArn: YOUR_CERTIFICATE_ARN

aws cloudfront update-distribution \
  --id YOUR_DISTRIBUTION_ID \
  --distribution-config file:///tmp/cf-config-updated.json \
  --if-match ETAG_FROM_GET_COMMAND
```

### Step 4: Update DNS

Add a CNAME record in your DNS provider:
```
kdlservices.com -> YOUR_DISTRIBUTION_DOMAIN.cloudfront.net
```

## Monitoring and Maintenance

### Check Deployment Status

```bash
# View CloudFront distribution status
aws cloudfront get-distribution \
  --id YOUR_DISTRIBUTION_ID \
  --query 'Distribution.Status'

# List S3 bucket contents
aws s3 ls s3://kdlservices-website-876169277867/
```

### View CloudFront Logs

Enable logging in CloudFront distribution settings to track access patterns.

### Cost Estimation

- **S3 Storage**: ~$0.023 per GB/month
- **S3 Requests**: ~$0.005 per 1,000 GET requests
- **CloudFront**: ~$0.085 per GB transferred (first 10 TB)
- **Typical small website**: $1-5/month

## Troubleshooting

### Issue: "Access Denied" when accessing CloudFront URL

**Solution**: Check that:
1. S3 bucket policy allows CloudFront OAI
2. CloudFront distribution status is "Deployed"
3. Files exist in S3 bucket

```bash
# Verify files in S3
aws s3 ls s3://kdlservices-website-876169277867/

# Check CloudFront status
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID \
  --query 'Distribution.Status'
```

### Issue: Changes not reflecting on website

**Solution**: CloudFront caches content. Either:
1. Wait for cache to expire (default: 24 hours)
2. Create invalidation (done automatically by GitHub Actions)
3. Manual invalidation:
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

### Issue: GitHub Actions deployment fails

**Solution**: Check:
1. AWS credentials are correctly set in GitHub Secrets
2. IAM user has sufficient permissions
3. S3 bucket name matches the workflow configuration
4. View detailed logs in GitHub Actions tab

## Cleanup (Destroying Resources)

To remove all AWS resources:

```bash
# Empty S3 bucket
aws s3 rm s3://kdlservices-website-876169277867/ --recursive

# Delete S3 bucket
aws s3api delete-bucket \
  --bucket kdlservices-website-876169277867 \
  --region us-west-1

# Disable CloudFront distribution (required before deletion)
aws cloudfront get-distribution-config \
  --id YOUR_DISTRIBUTION_ID > /tmp/cf-config.json

# Edit config to set Enabled: false, then update
aws cloudfront update-distribution \
  --id YOUR_DISTRIBUTION_ID \
  --distribution-config file:///tmp/cf-config-disabled.json \
  --if-match ETAG

# Wait for distribution to disable, then delete
aws cloudfront delete-distribution \
  --id YOUR_DISTRIBUTION_ID \
  --if-match ETAG
```

## Architecture Diagram

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────┐
│   CloudFront    │ (CDN, HTTPS, Caching)
│  Distribution   │
└────────┬────────┘
         │ via OAI
         ▼
┌─────────────────┐
│   S3 Bucket     │ (Static website hosting)
│  (Private)      │
└─────────────────┘
         ▲
         │ sync
┌─────────────────┐
│ GitHub Actions  │ (CI/CD Pipeline)
└─────────────────┘
```

## Support

For issues or questions:
- AWS Documentation: https://docs.aws.amazon.com/
- GitHub Actions: https://docs.github.com/actions
- CloudFront: https://docs.aws.amazon.com/cloudfront/
- S3: https://docs.aws.amazon.com/s3/
