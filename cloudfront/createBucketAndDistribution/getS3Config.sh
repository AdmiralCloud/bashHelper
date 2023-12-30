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

# Check if bucket name is provided
if [ "$#" -lt 1 ]; then
    log "Usage: $0 <bucket-name> [aws-profile]"
    exit 1
fi

BUCKET_NAME=$1
AWS_PROFILE=${2:-default.mfa}
OUTPUT_FILE="s3_config_output.json"

log "Setting AWS profile to ${AWS_PROFILE}..."
export AWS_PROFILE

# Helper function to check if the command output is valid JSON
is_valid_json() {
    echo "$1" | jq empty > /dev/null 2>&1
    return $?
}

log "Initializing JSON object..."
echo "{}" > $OUTPUT_FILE

# Retrieve various configurations and append to JSON object
for config in Policy ACL Cors Versioning Lifecycle Website Encryption Logging Tagging PublicAccessBlock; do
    lower_config=$(echo "$config" | awk '{print tolower($0)}') # Convert to lowercase
    log "Retrieving $config configuration..."
    output=$(aws s3api "get-bucket-${lower_config}" --bucket "$BUCKET_NAME" 2> /dev/null)
    
    if [ -n "$output" ] && is_valid_json "$output"; then
        jq --arg key "${config}" --argjson value "$output" '. + {($key): $value}' $OUTPUT_FILE > $OUTPUT_FILE.tmp && mv $OUTPUT_FILE.tmp $OUTPUT_FILE
        log "$config configuration retrieved successfully."
    else
        log "No $config configuration found or unable to retrieve."
    fi
done

log "S3 bucket configuration for $BUCKET_NAME saved to $OUTPUT_FILE."
