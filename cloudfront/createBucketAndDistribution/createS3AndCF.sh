#!/bin/bash

# Initialize variables with default values
AWS_PROFILE="default.mfa"
AWS_REGION="eu-central-1"
BUCKET_NAME=""
S3_CONFIG_TEMPLATE="s3_config_template.json"
CLOUDFRONT_CONFIG_TEMPLATE="cloudfront_config_template.json"
PLACEHOLDER_CONFIG="placeholder_config.json"

# Parse command line options
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    -b|--bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    --s3-config-template)
      S3_CONFIG_TEMPLATE="$2"
      shift 2
      ;;
    --cloudfront-config-template)
      CLOUDFRONT_CONFIG_TEMPLATE="$2"
      shift 2
      ;;
    --placeholder-config)
      PLACEHOLDER_CONFIG="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $key"
      exit 1
      ;;
  esac
done

# Check if the required BUCKET_NAME parameter is provided
if [ -z "$BUCKET_NAME" ]; then
  echo "Usage: $0 -b BUCKET_NAME [OPTIONS]"
  echo "Options:"
  echo "  --profile PROFILE               AWS profile (default: default.mfa)"
  echo "  --region REGION                 AWS region (default: eu-central-1)"
  echo "  --s3-config-template TEMPLATE      S3 config template file (default: s3_config_template.json)"
  echo "  --cloudfront-config-template TEMPLATE  CloudFront config template file (default: cloudfront_config_template.json)"
  echo "  --placeholder-config FILE           Placeholder config file (default: placeholder_config.json)"
  exit 1
fi


# Set AWS profile and region
export AWS_PROFILE
export AWS_DEFAULT_REGION=$AWS_REGION

# Retrieve AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve AWS Account ID."
    exit 1
fi

# Load placeholder values from the configuration file
if [ ! -f "$PLACEHOLDER_CONFIG" ]; then
    echo "Placeholder configuration file not found: $PLACEHOLDER_CONFIG"
    exit 1
fi

# Load values from the configuration file
while IFS="=" read -r key value; do
    declare $key="$value"
done < <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" $PLACEHOLDER_CONFIG)

### preparations end

### S3 CREATE BUCKET

# Function to check and handle create-bucket errors
handle_create_bucket_error() {
    if [[ $1 == *"BucketAlreadyOwnedByYou"* ]]; then
        echo "Bucket already exists and is owned by you."
    else
        echo "Error creating S3 bucket: $1"
        exit 1
    fi
}


# Replace placeholders in the S3 configuration template
if [ ! -f "$S3_CONFIG_TEMPLATE" ]; then
    echo "S3 configuration template not found: $S3_CONFIG_TEMPLATE"
    exit 1
fi

PROCESSED_S3_CONFIG="s3_config_processed.json"
sed -e "s/{{S3_GRANTEE}}/$S3_GRANTEE/g" \
    -e "s/{{S3_OWNER_ID}}/$S3_OWNER_ID/g" \
    "$S3_CONFIG_TEMPLATE" > "$PROCESSED_S3_CONFIG"


# Create S3 bucket with or without LocationConstraint based on the region
if [ "$AWS_REGION" == "us-east-1" ]; then
    CREATE_BUCKET_OUTPUT=$(aws s3api create-bucket --bucket "$BUCKET_NAME" 2>&1) || handle_create_bucket_error "$CREATE_BUCKET_OUTPUT"
else
    CREATE_BUCKET_OUTPUT=$(aws s3api create-bucket --bucket "$BUCKET_NAME" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>&1) || handle_create_bucket_error "$CREATE_BUCKET_OUTPUT"
fi

# Define the Public Access Block configuration
PUBLIC_ACCESS_BLOCK_CONFIG='{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
}'

# Apply the Public Access Block configuration
aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration "$PUBLIC_ACCESS_BLOCK_CONFIG"

# Apply Encryption configuration
ENCRYPTION_CONFIG=$(jq '.Encryption.ServerSideEncryptionConfiguration' "$PROCESSED_S3_CONFIG")
aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration "$ENCRYPTION_CONFIG"

### CLOUDFRONT
# Temporarily set AWS region to us-east-1 for CloudFront distribution creation
ORIGINAL_AWS_REGION=$AWS_REGION
export AWS_REGION="us-east-1"

# Generate a unique CallerReference, e.g., using current timestamp
CALLER_REFERENCE=$(date +%s)

# Replace placeholders in the CloudFront configuration template
if [ ! -f "$CLOUDFRONT_CONFIG_TEMPLATE" ]; then
    echo "CloudFront configuration template not found: $CLOUDFRONT_CONFIG_TEMPLATE"
    exit 1
fi

PROCESSED_CLOUDFRONT_CONFIG="cloudfront_config_processed.json"
sed -e "s/{{BUCKET_NAME}}/$BUCKET_NAME/g" \
    -e "s/{{ACCOUNT_ID}}/$ACCOUNT_ID/g" \
    -e "s/{{CERTIFICATE}}/$CERTIFICATE/g" \
    -e "s/{{ORIGIN_ACCESS_CONTROL_ID}}/$ORIGIN_ACCESS_CONTROL_ID/g" \
    -e "s/{{CACHE_POLICY_ID}}/$CACHE_POLICY_ID/g" \
    -e "s/{{ORIGIN_REQUEST_POLICY_ID}}/$ORIGIN_REQUEST_POLICY_ID/g" \
    -e "s/{{RESPONSE_HEADERS_POLICY_ID_1}}/$RESPONSE_HEADERS_POLICY_ID_1/g" \
    -e "s/{{RESPONSE_HEADERS_POLICY_ID_2}}/$RESPONSE_HEADERS_POLICY_ID_2/g" \
    -e "s/{{CALLER_REFERENCE}}/$CALLER_REFERENCE/g" \
    "$CLOUDFRONT_CONFIG_TEMPLATE" > "$PROCESSED_CLOUDFRONT_CONFIG"

# Extract the CNAME from the processed CloudFront config
CNAME=$(jq -r '.Aliases.Items[0]' "$PROCESSED_CLOUDFRONT_CONFIG")

# Check if a distribution with this CNAME already exists
CLOUDFRONT_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Aliases.Items!=null && contains(Aliases.Items, '$CNAME')].Id" \
    --output text)

if [ -n "$CLOUDFRONT_ID" ]; then
    echo "Updating existing CloudFront distribution with CNAME $CNAME: $CLOUDFRONT_DIST_ID"

    # Fetch the current configuration and ETag
    CURRENT_CONFIG=$(aws cloudfront get-distribution-config --id "$CLOUDFRONT_ID")
    ETAG=$(echo "$CURRENT_CONFIG" | jq -r '.ETag')

    # Load the template file into a variable
    TEMPLATE_CONFIG=$(<"$PROCESSED_CLOUDFRONT_CONFIG")

    # Extract values from the template file
    NEW_CACHE_BEHAVIOUR=$(echo "$TEMPLATE_CONFIG" | jq '.CacheBehaviors')
    NEW_DEFAULT_CACHE_BEHAVIOUR=$(echo "$TEMPLATE_CONFIG" | jq '.DefaultCacheBehavior')
    NEW_VIEWER_CERTIFICATE=$(echo "$TEMPLATE_CONFIG" | jq '.ViewerCertificate')
    NEW_COMMENT=$(echo "$TEMPLATE_CONFIG" | jq '.Comment')

    # Extract the existing distribution configuration from CURRENT_CONFIG
    EXISTING_CONFIG=$(echo "$CURRENT_CONFIG" | jq -r '.DistributionConfig')

    # Update the specific fields in the existing configuration
    MODIFIED_CONFIG=$(echo "$EXISTING_CONFIG" | jq ".ViewerCertificate = $NEW_VIEWER_CERTIFICATE | .Comment = $NEW_COMMENT | .CacheBehaviors = $NEW_CACHE_BEHAVIOUR | .DefaultCacheBehavior = $NEW_DEFAULT_CACHE_BEHAVIOUR")

    # Update the existing CloudFront distribution with the modified configuration
    DOMAIN_NAME=$(aws cloudfront update-distribution --id "$CLOUDFRONT_ID" --if-match "$ETAG" --distribution-config "$MODIFIED_CONFIG" --query 'Distribution.DomainName' --output text)

else
    echo "Creating new CloudFront distribution"

    DISTRIBUTION_INFO=$(aws cloudfront create-distribution --distribution-config file://"$PROCESSED_CLOUDFRONT_CONFIG" \
    --query '{Id: Distribution.Id, DomainName: Distribution.DomainName}' --output json) || { echo "Error: Unable to create CloudFront distribution."; exit 1; }

    # Extract the Distribution ID and Domain Name
    CLOUDFRONT_ID=$(echo "$DISTRIBUTION_INFO" | jq -r '.Id')
    DOMAIN_NAME=$(echo "$DISTRIBUTION_INFO" | jq -r '.DomainName')

    echo "CloudFront Distribution ID: $CLOUDFRONT_ID"
fi

export AWS_REGION=$ORIGINAL_AWS_REGION
# Generate and apply the bucket policy including the CloudFront Distribution ID
BUCKET_POLICY=$(cat <<EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [{
        "Sid": "AllowCloudFrontServicePrincipal",
        "Effect": "Allow",
        "Principal": {
            "Service": "cloudfront.amazonaws.com"
        },
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::$BUCKET_NAME/*",
        "Condition": {
            "StringEquals": {
            "AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT_ID:distribution/$CLOUDFRONT_ID"
            }
        }
    }]
}
EOF
)

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$BUCKET_POLICY"


echo "Resources prepared and configured successfully."
echo "S3 Bucket: $BUCKET_NAME"
echo "Cloudfront ID: $CLOUDFRONT_ID"
echo "Cloudfront Domain: $DOMAIN_NAME"
