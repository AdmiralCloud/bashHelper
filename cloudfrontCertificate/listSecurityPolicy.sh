#!/bin/bash

# Available policies
# https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

PROFILE=default.mfa
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if test -f "${SCRIPTPATH}/config.txt"; then
  source $SCRIPTPATH/config.txt
fi

# PROFILE
read -e -p "Please enter your profile or leave empty for default [${PROFILE}]: " input
PROFILE="${input:-$PROFILE}"


# Print the table header
echo "| Distribution ID | Security Policy | CNAMEs             |"
echo "|-----------------|-----------------|--------------------|"

# Define a function to fetch and process distributions based on pagination token
fetch_distributions() {
    local next_token="$1"
    
    if [ -z "$next_token" ]; then
        DISTRIBUTIONS=$(aws cloudfront list-distributions --profile "$PROFILE" --max-items 100 --query 'DistributionList.Items[?Enabled==`true`]' --output json)
    else
        DISTRIBUTIONS=$(aws cloudfront list-distributions --profile "$PROFILE" --max-items 100 --starting-token "$next_token" --query 'DistributionList.Items[?Enabled==`true`]' --output json)
    fi
    
    # Process the JSON with jq, ensuring that we handle null CNAMEs and add leading and trailing pipe symbols
    echo "$DISTRIBUTIONS" | jq -r '.[] | "| \(.Id) | \(.ViewerCertificate.MinimumProtocolVersion) | \((.Aliases.Items // []) | join(", ")) |"'
}


# Fetch and display the first batch of enabled distributions
fetch_distributions

# Check for more enabled distributions and fetch them
while [ $(aws cloudfront list-distributions --profile "$PROFILE" --query 'DistributionList.IsTruncated' --output text) == "true" ]; do
    NEXT_TOKEN=$(aws cloudfront list-distributions --profile "$PROFILE" --query 'DistributionList.NextMarker' --output text)
    fetch_distributions "$NEXT_TOKEN"
done
