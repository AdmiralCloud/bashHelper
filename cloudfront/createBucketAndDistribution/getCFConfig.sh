#!/bin/bash

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Checking prerequisites..."

# Check for AWS CLI
if ! command -v aws &> /dev/null
then
    log "Error: AWS CLI not installed. Please install it first."
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null
then
    log "Error: jq not installed. Please install it first."
    exit 1
fi

# Check if distribution ID is provided
if [ "$#" -lt 1 ]; then
    log "Usage: $0 <distribution-id> [aws-profile]"
    exit 1
fi

DISTRIBUTION_ID=$1
AWS_PROFILE=${2:-default.mfa}
OUTPUT_FILE="cloudfront_config_${DISTRIBUTION_ID}.json"

log "Setting AWS profile to ${AWS_PROFILE}..."
export AWS_PROFILE

log "Retrieving CloudFront distribution configuration for ID: $DISTRIBUTION_ID..."

# Retrieve the current configuration of the CloudFront distribution
config=$(aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID")

# Check if the retrieval was successful
if [ -z "$config" ]; then
    log "Error: Unable to retrieve configuration for CloudFront Distribution ID $DISTRIBUTION_ID"
    exit 1
fi

log "Processing and saving the configuration to $OUTPUT_FILE..."

# Saving the configuration to a file
echo "$config" | jq . > "$OUTPUT_FILE"

log "CloudFront distribution configuration saved to $OUTPUT_FILE."
