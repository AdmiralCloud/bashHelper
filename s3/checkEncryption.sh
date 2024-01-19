#!/bin/bash

# Check if AWS profile is passed as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <aws-profile>"
    exit 1
fi

AWS_PROFILE=$1

# Function to get encryption details of a bucket
get_encryption_details() {
    bucket_name=$1
    encryption_info=$(aws s3api get-bucket-encryption --bucket $bucket_name --profile $AWS_PROFILE 2>&1)

    if [[ $encryption_info == *"ServerSideEncryptionConfigurationNotFoundError"* ]]; then
        echo "Not Encrypted | -"
    else
        encryption_type=$(echo $encryption_info | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm')
        kms_master_key_id=$(echo $encryption_info | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID')

        if [ "$kms_master_key_id" != "null" ]; then
            echo "$encryption_type | SSE-KMS"
        else
            echo "$encryption_type | SSE-S3"
        fi
    fi
}

# File to store the table
output_file="bucket_encryption_details_$AWS_PROFILE.md"

# Print and write the table header
table_header="| Bucket Name | Encryption Algorithm | Encryption Type |"
echo "$table_header"
echo "$table_header" > $output_file

table_divider="|-------------|----------------------|-----------------|"
echo "$table_divider"
echo "$table_divider" >> $output_file

# Get list of all S3 buckets
BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text --profile $AWS_PROFILE)

# Loop through each bucket and get encryption details
for bucket in $BUCKETS; do
    details=$(get_encryption_details $bucket)
    table_row="| $bucket | $details |"
    echo "$table_row"
    echo "$table_row" >> $output_file
done
