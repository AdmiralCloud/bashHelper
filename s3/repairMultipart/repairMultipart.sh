#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
AWS_PROFILE="default.mfa"
S3_BUCKET=${1:-""} # Takes first parameter as bucket or empty string

# Function to get the number of parts for an upload
get_parts_count() {
    local bucket=$1
    local key=$2
    local upload_id=$3
    
    local parts=$(aws s3api list-parts \
        --profile $AWS_PROFILE \
        --bucket "$bucket" \
        --key "$key" \
        --upload-id "$upload_id" \
        --output json 2>/dev/null)
    
    if [ -z "$parts" ] || [ "$parts" == "null" ]; then
        echo "0"
        return
    fi
    
    local count=$(echo "$parts" | jq -r '.Parts | length')
    echo "${count:-0}"
}

# Function to repair an upload
repair_upload() {
    local bucket=$1
    local key=$2
    local upload_id=$3

    echo -e "\n${YELLOW}Checking parts for upload:${NC} $key"
    
    # List parts
    parts=$(aws s3api list-parts \
        --profile $AWS_PROFILE \
        --bucket "$bucket" \
        --key "$key" \
        --upload-id "$upload_id" \
        --query 'Parts[*].[PartNumber,Size,ETag]' \
        --output json)
    
    if [ -z "$parts" ] || [ "$parts" == "null" ]; then
        echo -e "${RED}No parts found for this upload.${NC}"
        return 1
    fi

    # Show parts
    echo -e "\n${BLUE}Found parts:${NC}"
    echo "─────────────────────────────────────────"
    echo "$parts" | jq -r '.[] | "Part \(.[0]): \(.[1]) bytes, ETag: \(.[2])"'
    echo "─────────────────────────────────────────"

    # Prepare JSON for complete-multipart-upload
    parts_json=$(echo "$parts" | jq '{Parts: [.[] | {PartNumber: .[0], ETag: .[2]}]}')

    read -e -p "Do you want to try completing this upload? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Attempting to complete upload...${NC}"
        
        # Complete upload
        if aws s3api complete-multipart-upload \
            --profile $AWS_PROFILE \
            --bucket "$bucket" \
            --key "$key" \
            --upload-id "$upload_id" \
            --multipart-upload "$parts_json"; then
            echo -e "${GREEN}Upload successfully completed!${NC}"
            return 0
        else
            echo -e "${RED}Error completing the upload.${NC}"
            return 1
        fi
    fi
}

# Function to process a single bucket
process_bucket() {
    local bucket=$1
    echo -e "\n${YELLOW}Searching for incomplete multipart uploads in $bucket...${NC}"
    
    # Get uploads in JSON format with extended information
    uploads=$(aws s3api list-multipart-uploads \
        --profile $AWS_PROFILE \
        --bucket "$bucket" \
        --query 'Uploads[*].[Key,UploadId,Initiated,Initiator.DisplayName]' \
        --output json 2>/dev/null)
    
    # Check if there are no uploads or if the command failed
    if [ -z "$uploads" ] || [ "$uploads" == "null" ] || [ "$uploads" == "[]" ]; then
        echo -e "${GREEN}No incomplete multipart uploads found.${NC}"
        if [ "$1" != "silent" ]; then
            read -e -p "Press Enter to continue..."
        fi
        return
    fi
    
    # Display uploads with numbers
    local upload_count=0
    echo -e "\n${BLUE}Found incomplete uploads:${NC}"
    echo "─────────────────────────────────────────────"
    
    # Arrays for storing upload information
    declare -a keys
    declare -a upload_ids
    
    while IFS=$'\t' read -e -r key upload_id initiated initiator; do
        # Skip if any of the required fields are empty
        if [ -z "$key" ] || [ -z "$upload_id" ]; then
            continue
        fi
        
        ((upload_count++))
        keys[$upload_count]=$key
        upload_ids[$upload_count]=$upload_id
        
        # Get number of parts for this upload
        parts_count=$(get_parts_count "$bucket" "$key" "$upload_id")
        
        echo -e "${GREEN}[$upload_count]${NC}"
        echo -e "${YELLOW}Key:${NC} $key"
        echo -e "${YELLOW}Upload ID:${NC} $upload_id"
        echo -e "${YELLOW}Started:${NC} $initiated"
        echo -e "${YELLOW}Initiator:${NC} $initiator"
        echo -e "${YELLOW}Available Parts:${NC} $parts_count"
        echo "─────────────────────────────────────────────"
    done < <(echo "$uploads" | jq -r '.[] | @tsv')
    
    if [ $upload_count -eq 0 ]; then
        echo -e "${GREEN}No incomplete multipart uploads found.${NC}"
        if [ "$1" != "silent" ]; then
            read -e -p "Press Enter to continue..."
        fi
        return
    fi
    
    # Action menu
    while true; do
        echo -e "\n${BLUE}Actions:${NC}"
        echo "1) Repair upload (enter number)"
        echo "2) Abort upload (enter number)"
        echo "3) Back to bucket selection"
        echo "4) Exit"
        
        read -e -p "Choose an action (1-4): " action
        
        case $action in
            1)
                read -e -p "Number of upload to repair (1-$upload_count): " upload_num
                if [[ "$upload_num" =~ ^[0-9]+$ ]] && [ "$upload_num" -ge 1 ] && [ "$upload_num" -le $upload_count ]; then
                    repair_upload "$bucket" "${keys[$upload_num]}" "${upload_ids[$upload_num]}"
                    if [ $? -eq 0 ]; then
                        echo -e "\n${GREEN}Refreshing upload list...${NC}"
                        sleep 1  # Give AWS a moment to update
                        process_bucket "$bucket"
                        return
                    fi
                else
                    echo -e "${RED}Invalid upload number${NC}"
                fi
                ;;
            2)
                read -e -p "Number of upload to abort (1-$upload_count): " upload_num
                if [[ "$upload_num" =~ ^[0-9]+$ ]] && [ "$upload_num" -ge 1 ] && [ "$upload_num" -le $upload_count ]; then
                    echo -e "\n${RED}Aborting upload:${NC} ${keys[$upload_num]}"
                    aws s3api abort-multipart-upload \
                        --profile $AWS_PROFILE \
                        --bucket "$bucket" \
                        --key "${keys[$upload_num]}" \
                        --upload-id "${upload_ids[$upload_num]}"
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Upload successfully aborted.${NC}"
                        echo -e "\n${GREEN}Refreshing upload list...${NC}"
                        sleep 1  # Give AWS a moment to update
                        process_bucket "$bucket"
                        return
                    else
                        echo -e "${RED}Error aborting the upload.${NC}"
                    fi
                else
                    echo -e "${RED}Invalid upload number${NC}"
                fi
                ;;
            3)
                return
                ;;
            4)
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid selection${NC}"
                ;;
        esac
    done
}

# Main function
main() {
    # If a bucket was passed as parameter
    if [ ! -z "$S3_BUCKET" ]; then
        if aws s3api head-bucket --profile $AWS_PROFILE --bucket "$S3_BUCKET" 2>/dev/null; then
            process_bucket "$S3_BUCKET"
        else
            echo -e "${RED}Bucket '$S3_BUCKET' doesn't exist or is not accessible${NC}"
            exit 1
        fi
        return
    fi

    # If no bucket was specified, show selection
    while true; do
        echo -e "\n${BLUE}Available S3 Buckets:${NC}"
        buckets=$(aws s3api list-buckets --profile $AWS_PROFILE --query 'Buckets[].Name' --output text)
        
        if [ -z "$buckets" ]; then
            echo -e "${RED}No buckets found or error accessing AWS${NC}"
            exit 1
        fi
        
        # Number and display buckets
        IFS=$'\t' read -e -r -a bucket_array <<< "$buckets"
        for i in "${!bucket_array[@]}"; do
            echo "$((i+1))) ${bucket_array[$i]}"
        done
        echo "$((${#bucket_array[@]}+1))) Exit"
        
        read -e -p "Choose a bucket (1-$((${#bucket_array[@]}+1))): " bucket_choice
        
        if [ "$bucket_choice" -eq "$((${#bucket_array[@]}+1))" ]; then
            echo -e "${GREEN}Program terminated.${NC}"
            exit 0
        fi
        
        if [ "$bucket_choice" -lt 1 ] || [ "$bucket_choice" -gt "${#bucket_array[@]}" ]; then
            echo -e "${RED}Invalid selection${NC}"
            continue
        fi
        
        selected_bucket="${bucket_array[$((bucket_choice-1))]}"
        process_bucket "$selected_bucket"
    done
}

# Start script
echo -e "${GREEN}Multipart Upload Manager${NC}"
echo -e "${YELLOW}Using AWS Profile: $AWS_PROFILE${NC}"
if [ ! -z "$S3_BUCKET" ]; then
    echo -e "${YELLOW}Working with bucket: $S3_BUCKET${NC}"
fi
main