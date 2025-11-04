#!/bin/bash

# AWS Infrastructure Setup Script
# This script creates the necessary AWS resources for hosting a static website

set -e

# Configuration
AWS_REGION="us-west-1"
AWS_ACCOUNT_ID="876169277867"
S3_BUCKET="kdlservices-website-${AWS_ACCOUNT_ID}"
CLOUDFRONT_OAI_COMMENT="KDLServices Website OAI"

echo "=========================================="
echo "AWS Static Website Infrastructure Setup"
echo "=========================================="
echo "Region: ${AWS_REGION}"
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "S3 Bucket: ${S3_BUCKET}"
echo "=========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed. Please install it first."
    echo "Visit: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity --region ${AWS_REGION} &> /dev/null; then
    echo "ERROR: AWS credentials are not configured properly."
    echo "Run: aws configure"
    exit 1
fi
echo "✓ AWS credentials verified"
echo ""

# Create S3 bucket
echo "Creating S3 bucket: ${S3_BUCKET}"
if aws s3 ls "s3://${S3_BUCKET}" 2>/dev/null; then
    echo "✓ Bucket already exists"
else
    # Note: us-west-1 requires LocationConstraint
    aws s3api create-bucket \
        --bucket ${S3_BUCKET} \
        --region ${AWS_REGION} \
        --create-bucket-configuration LocationConstraint=${AWS_REGION}
    echo "✓ Bucket created successfully"
fi
echo ""

# Block public access to S3 bucket (CloudFront will access via OAI)
echo "Configuring S3 bucket public access block..."
aws s3api put-public-access-block \
    --bucket ${S3_BUCKET} \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "✓ Public access blocked"
echo ""

# Enable static website hosting on S3
echo "Enabling static website hosting..."
aws s3 website "s3://${S3_BUCKET}/" \
    --index-document index.html \
    --error-document index.html
echo "✓ Static website hosting enabled"
echo ""

# Create CloudFront Origin Access Identity (OAI)
echo "Creating CloudFront Origin Access Identity..."
OAI_OUTPUT=$(aws cloudfront create-cloud-front-origin-access-identity \
    --cloud-front-origin-access-identity-config \
        CallerReference="kdlservices-$(date +%s)",Comment="${CLOUDFRONT_OAI_COMMENT}" \
    --output json 2>/dev/null || echo "")

if [ -z "$OAI_OUTPUT" ]; then
    echo "Checking for existing OAI..."
    OAI_LIST=$(aws cloudfront list-cloud-front-origin-access-identities --output json)
    OAI_ID=$(echo $OAI_LIST | jq -r ".CloudFrontOriginAccessIdentityList.Items[] | select(.Comment==\"${CLOUDFRONT_OAI_COMMENT}\") | .Id" | head -1)

    if [ -z "$OAI_ID" ]; then
        echo "ERROR: Could not create or find OAI"
        exit 1
    fi
    echo "✓ Using existing OAI: ${OAI_ID}"
else
    OAI_ID=$(echo $OAI_OUTPUT | jq -r '.CloudFrontOriginAccessIdentity.Id')
    echo "✓ OAI created: ${OAI_ID}"
fi

OAI_CANONICAL_USER_ID=$(aws cloudfront get-cloud-front-origin-access-identity \
    --id ${OAI_ID} --output json | jq -r '.CloudFrontOriginAccessIdentity.S3CanonicalUserId')
echo "✓ OAI Canonical User ID: ${OAI_CANONICAL_USER_ID}"
echo ""

# Create bucket policy to allow CloudFront OAI access
echo "Creating S3 bucket policy for CloudFront access..."
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontOAI",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${OAI_ID}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket ${S3_BUCKET} \
    --policy file:///tmp/bucket-policy.json
echo "✓ Bucket policy applied"
echo ""

# Create CloudFront distribution
echo "Creating CloudFront distribution..."
cat > /tmp/cf-distribution.json <<EOF
{
    "CallerReference": "kdlservices-$(date +%s)",
    "Comment": "KDLServices Website Distribution",
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-${S3_BUCKET}",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000,
        "Compress": true,
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        }
    },
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-${S3_BUCKET}",
                "DomainName": "${S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com",
                "S3OriginConfig": {
                    "OriginAccessIdentity": "origin-access-identity/cloudfront/${OAI_ID}"
                }
            }
        ]
    },
    "DefaultRootObject": "index.html",
    "Enabled": true,
    "CustomErrorResponses": {
        "Quantity": 1,
        "Items": [
            {
                "ErrorCode": 404,
                "ResponsePagePath": "/index.html",
                "ResponseCode": "200",
                "ErrorCachingMinTTL": 300
            }
        ]
    },
    "PriceClass": "PriceClass_100"
}
EOF

CF_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/cf-distribution.json \
    --output json)

CF_ID=$(echo $CF_OUTPUT | jq -r '.Distribution.Id')
CF_DOMAIN=$(echo $CF_OUTPUT | jq -r '.Distribution.DomainName')

echo "✓ CloudFront distribution created"
echo "  Distribution ID: ${CF_ID}"
echo "  Domain Name: ${CF_DOMAIN}"
echo ""

# Clean up temp files
rm -f /tmp/bucket-policy.json /tmp/cf-distribution.json

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Add GitHub Secrets to your repository:"
echo "   - AWS_ACCESS_KEY_ID: Your AWS access key"
echo "   - AWS_SECRET_ACCESS_KEY: Your AWS secret key"
echo "   - CLOUDFRONT_DISTRIBUTION_ID: ${CF_ID}"
echo ""
echo "2. Wait for CloudFront distribution to deploy (10-15 minutes)"
echo "   Check status: aws cloudfront get-distribution --id ${CF_ID} --query 'Distribution.Status'"
echo ""
echo "3. Access your website at: https://${CF_DOMAIN}"
echo ""
echo "4. (Optional) Set up custom domain:"
echo "   - Add CNAME record pointing to ${CF_DOMAIN}"
echo "   - Request SSL certificate in ACM (us-east-1 region)"
echo "   - Update CloudFront distribution with alternate domain name"
echo ""
echo "=========================================="
