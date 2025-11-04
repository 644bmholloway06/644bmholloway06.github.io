# Quick Start Guide - AWS Deployment

## 🚀 Deploy in 3 Steps

### 1️⃣ Run Setup Script

```bash
# Configure AWS CLI first
aws configure
# Enter: Access Key, Secret Key, Region: us-west-1

# Run the setup script
./scripts/setup-aws-infrastructure.sh
```

**Save the CloudFront Distribution ID** from the output!

### 2️⃣ Add GitHub Secrets

Go to: https://github.com/644bmholloway06/644bmholloway06.github.io/settings/secrets/actions

Add these 3 secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `CLOUDFRONT_DISTRIBUTION_ID` (from step 1)

### 3️⃣ Push to Main Branch

```bash
git add .
git commit -m "Deploy website"
git push origin main
```

Done! 🎉

## 📍 Find Your Website

Get your CloudFront URL:
```bash
aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='KDLServices Website Distribution'].DomainName" \
  --output text
```

Your website: `https://YOUR_CLOUDFRONT_DOMAIN.cloudfront.net`

## ⏱️ Timeline

- Setup script: ~2 minutes
- CloudFront deployment: ~10-15 minutes
- Each deployment: ~1-2 minutes

## 📚 Need More Help?

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete documentation.

## 🧹 Quick Commands

**Deploy manually:**
```bash
aws s3 sync . s3://kdlservices-website-876169277867/ \
  --exclude ".git/*" --exclude ".github/*" --delete --region us-west-1
```

**Clear cache:**
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_ID --paths "/*"
```

**Check status:**
```bash
aws cloudfront get-distribution --id YOUR_ID \
  --query 'Distribution.Status'
```
