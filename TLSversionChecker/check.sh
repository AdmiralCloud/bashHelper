#!/bin/bash

# Check if domain and AWS profile are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <domain> <aws_profile>"
    exit 1
fi

DOMAIN=$1
AWS_PROFILE=$2
OUTPUT_FILE="${DOMAIN}_tls_versions.md"

# Function to get TLS version
get_tls_version() {
    local subdomain=$1
    TLS_INFO=$(echo | openssl s_client -connect "$subdomain":443 2>&1)
    TLS_VERSION_LINE=$(echo "$TLS_INFO" | grep -o 'TLSv[0-9]\.[0-9]' | head -1)
    
    if [ -z "$TLS_VERSION_LINE" ]; then
        echo "N/A"
    else
        echo "$TLS_VERSION_LINE"
    fi
}

# Fetch hosted zone ID for the domain
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name $DOMAIN --profile $AWS_PROFILE --output text --query 'HostedZones[0].Id')

# Check if hosted zone ID is retrieved
if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Failed to retrieve hosted zone ID for $DOMAIN" | tee -a $OUTPUT_FILE
    exit 1
fi

# Fetch A and CNAME records from Route 53
echo "Fetching A and CNAME records for $DOMAIN from Route 53..." | tee -a $OUTPUT_FILE
RECORD_SETS=$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --profile $AWS_PROFILE --output text --query 'ResourceRecordSets[?Type==`A` || Type==`CNAME`].[Name]')

# Initialize Markdown table
echo "| Subdomain | TLS Version |" | tee $OUTPUT_FILE
echo "|-----------|-------------|" | tee -a $OUTPUT_FILE

# Check TLS version for each record, skipping "_domainkey" subdomains
while read -r record; do
    if [[ $record == *"_domainkey"* ]]; then
        continue
    fi
    subdomain=$(echo $record | sed 's/\.$//')  # Remove trailing dot
    TLS_VERSION=$(get_tls_version $subdomain)
    echo "| $subdomain | $TLS_VERSION |" | tee -a $OUTPUT_FILE
done <<< "$RECORD_SETS"
