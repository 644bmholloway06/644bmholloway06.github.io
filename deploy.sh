#!/bin/bash

# AWS Deployment Script for Static Website
# This script deploys a static website to AWS S3 with CloudFront CDN

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load configuration
if [ -f "deploy-config.env" ]; then
    source deploy-config.env
else
    echo -e "${RED}Error: deploy-config.env file not found${NC}"
    exit 1
fi

# Validate required variables
if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$AWS_REGION" ] || [ -z "$STACK_NAME" ] || [ -z "$BUCKET_NAME" ]; then
    echo -e "${RED}Error: Required configuration variables are missing${NC}"
    echo "Please check deploy-config.env file"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Static Website Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Stack Name: $STACK_NAME"
echo "Bucket Name: $BUCKET_NAME"
echo ""

# Check if AWS CLI is configured
echo -e "${YELLOW}Checking AWS CLI configuration...${NC}"
if ! aws sts get-caller-identity --region $AWS_REGION > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text --region $AWS_REGION)
if [ "$CURRENT_ACCOUNT" != "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Warning: Current AWS account ($CURRENT_ACCOUNT) does not match configured account ($AWS_ACCOUNT_ID)${NC}"
    read -p "Do you want to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}✓ AWS CLI configured successfully${NC}"
echo ""

# Deploy CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file cloudformation-template.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides BucketName=$BUCKET_NAME \
    --region $AWS_REGION \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ CloudFormation stack deployed successfully${NC}"
else
    echo -e "${RED}Error: CloudFormation deployment failed${NC}"
    exit 1
fi
echo ""

# Get stack outputs
echo -e "${YELLOW}Retrieving stack outputs...${NC}"
BUCKET_NAME_OUTPUT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
    --output text)

CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontURL`].OutputValue' \
    --output text)

CLOUDFRONT_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

echo -e "${GREEN}✓ Stack outputs retrieved${NC}"
echo ""

# Upload website files to S3
echo -e "${YELLOW}Uploading website files to S3...${NC}"
aws s3 sync . s3://$BUCKET_NAME_OUTPUT \
    --region $AWS_REGION \
    --exclude ".git/*" \
    --exclude "*.sh" \
    --exclude "*.yaml" \
    --exclude "*.yml" \
    --exclude "*.env" \
    --exclude "*.md" \
    --exclude ".gitignore" \
    --cache-control "max-age=3600" \
    --delete

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Files uploaded successfully${NC}"
else
    echo -e "${RED}Error: File upload failed${NC}"
    exit 1
fi
echo ""

# Invalidate CloudFront cache
echo -e "${YELLOW}Invalidating CloudFront cache...${NC}"
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id $CLOUDFRONT_ID \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text \
    --region $AWS_REGION)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ CloudFront cache invalidation created (ID: $INVALIDATION_ID)${NC}"
else
    echo -e "${YELLOW}Warning: CloudFront cache invalidation failed${NC}"
fi
echo ""

# Display deployment information
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your website is now deployed and accessible at:"
echo ""
echo -e "CloudFront URL: ${GREEN}https://$CLOUDFRONT_URL${NC}"
echo ""
echo "Note: CloudFront distribution may take 15-20 minutes to fully deploy."
echo "You can check the status in the AWS Console."
echo ""
echo -e "${YELLOW}Additional Information:${NC}"
echo "S3 Bucket: $BUCKET_NAME_OUTPUT"
echo "CloudFront Distribution ID: $CLOUDFRONT_ID"
echo "Region: $AWS_REGION"
echo ""
