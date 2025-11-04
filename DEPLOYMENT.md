# AWS Deployment Guide

This guide explains how to deploy your static website to AWS using S3 and CloudFront.

## Overview

This deployment package includes:
- **CloudFormation Template** (`cloudformation-template.yaml`): Infrastructure as Code
- **Deployment Script** (`deploy.sh`): Automated deployment script
- **Configuration File** (`deploy-config.env`): Deployment settings

## Architecture

Your website will be deployed with:
- **Amazon S3**: Static file hosting
- **Amazon CloudFront**: Content Delivery Network (CDN) for fast global access
- **CloudFormation**: Infrastructure management

## Prerequisites

1. **AWS Account**: Account ID `876169277867`
2. **AWS CLI**: Installed and configured
3. **IAM Permissions**: You need the following permissions:
   - CloudFormation (full access)
   - S3 (full access)
   - CloudFront (full access)
   - IAM (read access for role checking)

## Installation Steps

### Step 1: Install AWS CLI

If you haven't already installed the AWS CLI, follow these steps:

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
Download and run the AWS CLI MSI installer from [AWS website](https://aws.amazon.com/cli/)

### Step 2: Configure AWS CLI

Run the following command and enter your AWS credentials:

```bash
aws configure
```

You'll be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-west-1`
- Default output format: `json`

To verify your configuration:
```bash
aws sts get-caller-identity
```

This should return your account ID: `876169277867`

### Step 3: Review Configuration

Open `deploy-config.env` and verify the settings:

```bash
AWS_ACCOUNT_ID="876169277867"
AWS_REGION="us-west-1"
STACK_NAME="brad-holloway-website-stack"
BUCKET_NAME="brad-holloway-website-876169277867"
```

**Important**: S3 bucket names must be globally unique. If deployment fails with a bucket name conflict, edit `BUCKET_NAME` in `deploy-config.env` to a unique value.

### Step 4: Deploy Your Website

Run the deployment script:

```bash
./deploy.sh
```

The script will:
1. Validate AWS credentials
2. Create/update CloudFormation stack
3. Upload website files to S3
4. Invalidate CloudFront cache
5. Display your website URL

**Note**: Initial CloudFront distribution deployment takes 15-20 minutes.

## Deployment Details

### What Gets Deployed?

The deployment script uploads all files except:
- `.git/` directory
- `*.sh` scripts
- `*.yaml` CloudFormation templates
- `*.env` configuration files
- `*.md` documentation files
- `.gitignore` file

### CloudFormation Resources

The stack creates:
1. **S3 Bucket**: Stores your website files
2. **Bucket Policy**: Allows public read access
3. **CloudFront Distribution**: CDN for fast content delivery
4. **Origin Access Control**: Secure access from CloudFront to S3

## Updating Your Website

To update your website after making changes:

1. Edit your HTML/CSS/JS files
2. Run the deployment script again:
   ```bash
   ./deploy.sh
   ```

The script will:
- Upload only changed files
- Invalidate CloudFront cache
- Make updates available within minutes

## Cost Considerations

AWS services have associated costs:

- **S3**: ~$0.023 per GB/month for storage (first 50TB)
- **CloudFront**:
  - $0.085 per GB for first 10TB/month (data transfer)
  - $0.0075 per 10,000 requests
- **CloudFormation**: Free

**Estimated monthly cost** for a small website: $1-5/month

### AWS Free Tier

If your account is within the first 12 months:
- S3: 5GB of storage, 20,000 GET requests
- CloudFront: 50GB data transfer, 2,000,000 requests

## Cleanup / Deleting Resources

To delete all AWS resources and stop incurring costs:

```bash
# Delete all S3 bucket contents first
aws s3 rm s3://brad-holloway-website-876169277867 --recursive --region us-west-1

# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name brad-holloway-website-stack --region us-west-1

# Wait for stack deletion to complete
aws cloudformation wait stack-delete-complete --stack-name brad-holloway-website-stack --region us-west-1
```

## Troubleshooting

### Issue: "Bucket name already exists"

S3 bucket names are globally unique. Edit `BUCKET_NAME` in `deploy-config.env`:
```bash
BUCKET_NAME="brad-holloway-website-876169277867-unique-suffix"
```

### Issue: "Access Denied"

Ensure your AWS credentials have the necessary permissions:
- CloudFormation: `cloudformation:*`
- S3: `s3:*`
- CloudFront: `cloudfront:*`

### Issue: "CloudFront distribution not working"

CloudFront takes 15-20 minutes to deploy initially. Check status:
```bash
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID --region us-west-1
```

### Issue: "Changes not appearing"

1. Check if files were uploaded to S3:
   ```bash
   aws s3 ls s3://brad-holloway-website-876169277867/ --region us-west-1
   ```

2. CloudFront caching may delay updates. The script invalidates the cache, but it can take 5-15 minutes.

## Custom Domain Setup (Optional)

To use a custom domain (e.g., www.bradholloway.com):

1. Register a domain in Route 53 or external registrar
2. Request SSL certificate in AWS Certificate Manager (ACM) in `us-east-1` region
3. Update `cloudformation-template.yaml` to include:
   - Custom domain aliases
   - ACM certificate ARN
   - Route 53 DNS records
4. Redeploy the stack

## Security Considerations

- Website files are publicly accessible (required for static hosting)
- Never commit AWS credentials to Git
- Use IAM roles with minimum required permissions
- Enable CloudFront access logging for monitoring

## Monitoring and Logs

### View CloudFront Access Logs

Add to CloudFormation template:
```yaml
Logging:
  Bucket: your-logs-bucket.s3.amazonaws.com
  Prefix: cloudfront-logs/
```

### Monitor Costs

Set up billing alerts in AWS Console:
1. Go to AWS Billing Dashboard
2. Create a billing alarm
3. Set threshold (e.g., $10/month)

## Additional Resources

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)

## Support

For issues with this deployment package, check:
1. AWS CloudFormation console for stack errors
2. AWS CloudWatch logs for detailed error messages
3. Verify IAM permissions for your user

---

**Quick Reference Commands:**

```bash
# Deploy/Update website
./deploy.sh

# View CloudFormation stack status
aws cloudformation describe-stacks --stack-name brad-holloway-website-stack --region us-west-1

# List S3 bucket contents
aws s3 ls s3://brad-holloway-website-876169277867/ --region us-west-1

# Sync local changes to S3
aws s3 sync . s3://brad-holloway-website-876169277867/ --region us-west-1 --exclude ".git/*"

# Create CloudFront invalidation
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*" --region us-west-1
```
