#!/usr/bin/env python3
"""
KDL Services Website - S3 Deployment Script
This script will:
1. Create an IAM user for S3 operations (optional, requires root credentials)
2. Create an S3 bucket for website hosting
3. Configure the bucket for static website hosting
4. Upload website files
5. Set up public access policies
"""

import boto3
import json
import os
import sys
from botocore.exceptions import ClientError

# Configuration
BUCKET_NAME = "kdl-services-website"  # Change this to your preferred bucket name (must be globally unique)
REGION = "us-east-1"  # Change if needed
IAM_USER_NAME = "kdl-s3-deployer"
WEBSITE_DIR = os.path.dirname(os.path.abspath(__file__))  # Current directory

# AWS Credentials - Replace these with your actual credentials
AWS_ACCESS_KEY = os.environ.get("AWS_ACCESS_KEY_ID", "YOUR_ACCESS_KEY_HERE")
AWS_SECRET_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "YOUR_SECRET_KEY_HERE")

def create_iam_user(session):
    """Create IAM user with S3 access"""
    print("\n" + "="*60)
    print("Creating IAM User for S3")
    print("="*60)

    iam = session.client('iam')

    try:
        # Create IAM user
        print(f"Creating IAM user: {IAM_USER_NAME}...")
        iam.create_user(UserName=IAM_USER_NAME)
        print(f"✓ IAM user '{IAM_USER_NAME}' created successfully")
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"! IAM user '{IAM_USER_NAME}' already exists")
        else:
            print(f"✗ Error creating IAM user: {e}")
            return None

    try:
        # Attach S3 Full Access policy
        print(f"Attaching S3FullAccess policy...")
        iam.attach_user_policy(
            UserName=IAM_USER_NAME,
            PolicyArn='arn:aws:iam::aws:policy/AmazonS3FullAccess'
        )
        print(f"✓ Policy attached successfully")
    except ClientError as e:
        print(f"! Policy may already be attached: {e}")

    try:
        # Create access key
        print(f"Creating access keys...")
        response = iam.create_access_key(UserName=IAM_USER_NAME)
        access_key = response['AccessKey']

        print(f"\n{'='*60}")
        print(f"IAM USER CREDENTIALS - SAVE THESE!")
        print(f"{'='*60}")
        print(f"Access Key ID: {access_key['AccessKeyId']}")
        print(f"Secret Access Key: {access_key['SecretAccessKey']}")
        print(f"{'='*60}\n")

        return access_key
    except ClientError as e:
        print(f"✗ Error creating access keys: {e}")
        return None

def create_s3_bucket(s3_client):
    """Create S3 bucket"""
    print("\n" + "="*60)
    print(f"Creating S3 Bucket: {BUCKET_NAME}")
    print("="*60)

    try:
        if REGION == 'us-east-1':
            s3_client.create_bucket(Bucket=BUCKET_NAME)
        else:
            s3_client.create_bucket(
                Bucket=BUCKET_NAME,
                CreateBucketConfiguration={'LocationConstraint': REGION}
            )
        print(f"✓ Bucket '{BUCKET_NAME}' created successfully")
    except ClientError as e:
        if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
            print(f"! Bucket '{BUCKET_NAME}' already exists and is owned by you")
        else:
            print(f"✗ Error creating bucket: {e}")
            return False

    return True

def configure_website_hosting(s3_client):
    """Configure bucket for static website hosting"""
    print("\n" + "="*60)
    print("Configuring Static Website Hosting")
    print("="*60)

    try:
        # Disable Block Public Access
        print("Disabling Block Public Access...")
        s3_client.put_public_access_block(
            Bucket=BUCKET_NAME,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': False,
                'IgnorePublicAcls': False,
                'BlockPublicPolicy': False,
                'RestrictPublicBuckets': False
            }
        )
        print("✓ Public access enabled")
    except ClientError as e:
        print(f"✗ Error configuring public access: {e}")
        return False

    try:
        # Configure website
        print("Setting up website configuration...")
        s3_client.put_bucket_website(
            Bucket=BUCKET_NAME,
            WebsiteConfiguration={
                'IndexDocument': {'Suffix': 'kdl_home_page.html'},
                'ErrorDocument': {'Key': 'kdl_home_page.html'}
            }
        )
        print("✓ Website configuration set")
    except ClientError as e:
        print(f"✗ Error setting website configuration: {e}")
        return False

    try:
        # Set bucket policy for public read access
        print("Setting bucket policy for public access...")
        bucket_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "PublicReadGetObject",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": f"arn:aws:s3:::{BUCKET_NAME}/*"
                }
            ]
        }

        s3_client.put_bucket_policy(
            Bucket=BUCKET_NAME,
            Policy=json.dumps(bucket_policy)
        )
        print("✓ Bucket policy set for public access")
    except ClientError as e:
        print(f"✗ Error setting bucket policy: {e}")
        return False

    return True

def upload_website_files(s3_client):
    """Upload website files to S3"""
    print("\n" + "="*60)
    print("Uploading Website Files")
    print("="*60)

    # File mappings: (local_file, s3_key, content_type)
    files_to_upload = [
        ('kdl_home_page.html', 'kdl_home_page.html', 'text/html'),
        ('kdl_home_page.html', 'index.html', 'text/html'),  # Also upload as index.html
        ('kdl_home_page.css', 'kdl_home_page.css', 'text/css'),
        ('kdl_services_call_back_request.js', 'kdl_services_call_back_request.js', 'application/javascript'),
        ('KDL Services Logo.png', 'KDL Services Logo.png', 'image/png'),
    ]

    for local_file, s3_key, content_type in files_to_upload:
        file_path = os.path.join(WEBSITE_DIR, local_file)

        if not os.path.exists(file_path):
            print(f"⚠ Warning: File not found: {file_path}")
            continue

        try:
            print(f"Uploading {local_file}...")
            s3_client.upload_file(
                file_path,
                BUCKET_NAME,
                s3_key,
                ExtraArgs={
                    'ContentType': content_type,
                    'ACL': 'public-read'
                }
            )
            print(f"✓ Uploaded: {s3_key}")
        except ClientError as e:
            print(f"✗ Error uploading {local_file}: {e}")

    return True

def main():
    print("\n" + "="*60)
    print("KDL Services Website - S3 Deployment")
    print("="*60)

    # Create boto3 session
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY,
        region_name=REGION
    )

    # Verify credentials
    print("\nVerifying AWS credentials...")
    try:
        sts = session.client('sts')
        identity = sts.get_caller_identity()
        print(f"✓ Connected as: {identity['Arn']}")
        print(f"  Account: {identity['Account']}")
    except ClientError as e:
        print(f"✗ Error: Could not verify AWS credentials: {e}")
        sys.exit(1)

    # Ask if user wants to create IAM user
    print("\n" + "="*60)
    create_iam = input("Do you want to create an IAM user for S3 operations? (y/n): ").strip().lower()

    if create_iam == 'y':
        access_key = create_iam_user(session)
        if access_key:
            print("\n⚠ IMPORTANT: Save the IAM credentials above in a secure location!")
            print("  After this deployment, you should:")
            print("  1. Delete or disable the root access keys in AWS Console")
            print("  2. Use the new IAM user credentials for future operations")
            input("\nPress Enter to continue with deployment...")

    # Create S3 client
    s3_client = session.client('s3')

    # Create bucket
    if not create_s3_bucket(s3_client):
        print("\n✗ Failed to create bucket. Exiting.")
        sys.exit(1)

    # Configure website hosting
    if not configure_website_hosting(s3_client):
        print("\n✗ Failed to configure website hosting. Exiting.")
        sys.exit(1)

    # Upload files
    upload_website_files(s3_client)

    # Print website URL
    print("\n" + "="*60)
    print("DEPLOYMENT COMPLETE!")
    print("="*60)
    website_url = f"http://{BUCKET_NAME}.s3-website-{REGION}.amazonaws.com"
    print(f"\n🌐 Your website is now live at:")
    print(f"   {website_url}")
    print(f"\n📝 Note: The main page is accessible at:")
    print(f"   {website_url}/kdl_home_page.html")
    print(f"   {website_url}/index.html")
    print("\n" + "="*60)

if __name__ == "__main__":
    main()
