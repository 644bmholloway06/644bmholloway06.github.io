# KDL Services Website - AWS S3 Deployment Guide

This repository contains the KDL Services website and an automated deployment script to host it on Amazon S3.

## 📁 Repository Contents

- `kdl_home_page.html` - Main website HTML file
- `kdl_home_page.css` - Stylesheet
- `kdl_services_call_back_request.js` - JavaScript functionality
- `KDL Services Logo.png` - Company logo
- `deploy_to_s3.py` - Automated deployment script
- `index.html` - GitHub Pages placeholder

## 🚀 Quick Start - Deploy to S3

### Prerequisites

1. **Python 3.7+** installed on your machine
2. **AWS Account** with root or administrator access
3. **boto3** Python library

### Step 1: Install Dependencies

```bash
pip install boto3
```

### Step 2: Set Up AWS Credentials

You have two options:

#### Option A: Environment Variables (Recommended)
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
```

#### Option B: Edit the Script
Open `deploy_to_s3.py` and replace the placeholder values:
```python
AWS_ACCESS_KEY = "YOUR_ACCESS_KEY_HERE"
AWS_SECRET_KEY = "YOUR_SECRET_KEY_HERE"
```

### Step 3: Configure Bucket Settings (Optional)

Edit `deploy_to_s3.py` to customize:

```python
BUCKET_NAME = "kdl-services-website"  # Must be globally unique!
REGION = "us-east-1"  # Choose your preferred AWS region
IAM_USER_NAME = "kdl-s3-deployer"  # Name for the optional IAM user
```

**Important:** S3 bucket names must be globally unique. If `kdl-services-website` is taken, choose a different name like `kdl-services-yourname` or `kdl-services-website-2024`.

### Step 4: Run the Deployment Script

```bash
cd /path/to/this/repository
python3 deploy_to_s3.py
```

### Step 5: Follow the Prompts

The script will:

1. ✓ Verify your AWS credentials
2. ? Ask if you want to create an IAM user (recommended for security)
3. ✓ Create the S3 bucket
4. ✓ Configure static website hosting
5. ✓ Upload all website files
6. ✓ Set public access policies
7. 🌐 Display your website URL!

## 🔐 Security Best Practices

### Creating an IAM User (Recommended)

When prompted, select `y` to create a dedicated IAM user for S3 operations. The script will:

- Create a new IAM user named `kdl-s3-deployer`
- Attach the `AmazonS3FullAccess` policy
- Generate access keys for this user
- **Display the credentials (SAVE THESE!)**

After deployment:

1. **Save the IAM user credentials** in a secure location
2. **Delete or disable root access keys** in AWS Console:
   - Go to AWS Console → IAM → Users → Your Root User → Security Credentials
   - Delete or deactivate the root access keys
3. Use the IAM user credentials for future deployments

## 🌐 Accessing Your Website

After successful deployment, your website will be available at:

```
http://{BUCKET_NAME}.s3-website-{REGION}.amazonaws.com
```

For example:
- `http://kdl-services-website.s3-website-us-east-1.amazonaws.com`

The website will be accessible at both:
- `/kdl_home_page.html` - Original filename
- `/index.html` - Standard web root

## 📝 What the Script Does

1. **Creates S3 Bucket**: Sets up a new S3 bucket with your chosen name
2. **Disables Block Public Access**: Allows public access to website files
3. **Configures Website Hosting**: Sets up S3 for static website hosting
4. **Sets Bucket Policy**: Applies a public-read policy to all objects
5. **Uploads Files**: Transfers all website files with proper content types:
   - HTML files → `text/html`
   - CSS files → `text/css`
   - JavaScript files → `application/javascript`
   - Images → `image/png`
6. **Sets ACLs**: Makes all uploaded files publicly readable

## 🔧 Troubleshooting

### "Bucket already exists"
The bucket name is taken globally. Choose a different name in the script configuration.

### "Access Denied"
Your AWS credentials don't have sufficient permissions. Ensure you're using root or administrator credentials.

### "Invalid credentials"
Check that your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are correct.

### Files not uploading
Ensure all website files are in the same directory as the script.

## 🛠️ Manual Deployment (Alternative)

If you prefer to use AWS CLI:

```bash
# Create bucket
aws s3 mb s3://your-bucket-name

# Enable static website hosting
aws s3 website s3://your-bucket-name/ \
    --index-document kdl_home_page.html \
    --error-document kdl_home_page.html

# Upload files
aws s3 sync . s3://your-bucket-name/ \
    --exclude ".*" \
    --exclude "*.md" \
    --exclude "*.py" \
    --acl public-read

# Set bucket policy
aws s3api put-bucket-policy \
    --bucket your-bucket-name \
    --policy file://bucket-policy.json
```

## 📊 Cost Estimate

AWS S3 pricing (us-east-1):
- **Storage**: ~$0.023 per GB/month
- **Requests**: $0.0004 per 1,000 GET requests
- **Data Transfer**: First 100GB free, then $0.09/GB

For a small website like KDL Services (~1.5MB), expect:
- **Monthly cost**: < $1 USD (including reasonable traffic)

## 🔄 Updating Your Website

To update the website after making changes:

1. Edit your HTML/CSS/JS files locally
2. Run the deployment script again:
   ```bash
   python3 deploy_to_s3.py
   ```
3. Select `n` when asked about creating an IAM user (already exists)
4. Files will be re-uploaded with new content

## 🌍 Using a Custom Domain (Optional)

To use your own domain name:

1. Register a domain (e.g., through Route 53, GoDaddy, Namecheap)
2. In AWS Route 53, create a hosted zone for your domain
3. Create an A record (alias) pointing to your S3 bucket
4. Note: Bucket name must match your domain name for this to work

## 📞 Support

For issues with:
- **This script**: Check the troubleshooting section above
- **AWS Services**: Consult AWS documentation or support
- **Website content**: Contact KDL Services

## ⚠️ Important Notes

- The website will be **publicly accessible** to anyone with the URL
- AWS charges apply for storage and bandwidth usage
- Keep your AWS credentials secure and never commit them to version control
- The script includes your credentials - add it to `.gitignore` if sharing code

---

**Ready to deploy?** Run `python3 deploy_to_s3.py` and follow the prompts!
