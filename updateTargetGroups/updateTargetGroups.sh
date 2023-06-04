#!/bin/bash

# Default values
DEFAULT_OPERATION="register"
DEFAULT_CONFIG_FILE="apiServer.txt"
DEFAULT_INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"
DEFAULT_PROFILE=default.mfa

# Get the operation, instance ID and config file from the command line or use defaults
CONFIG_FILE=${1:-$DEFAULT_CONFIG_FILE}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

read -p "Please enter instance ID [$DEFAULT_INSTANCE_ID]: " INSTANCE_ID
INSTANCE_ID=${INSTANCE_ID:-$DEFAULT_INSTANCE_ID}

read -p "Please enter operation [$DEFAULT_OPERATION]: " OPERATION
OPERATION=${OPERATION:-$DEFAULT_OPERATION}

read -p "Which AWS Profile to use? [$DEFAULT_PROFILE]: " PROFILE
PROFILE=${PROFILE:-$DEFAULT_PROFILE}

# Load target groups from the config file
TARGET_GROUP_ARNS=()
while IFS= read -r line; do
    TARGET_GROUP_ARNS+=("$line")
done < "$CONFIG_FILE"

# Check if config file was empty
if [ ${#TARGET_GROUP_ARNS[@]} -eq 0 ]; then
    echo "Error: config file is empty - please add target groups (one per line)"
    exit 1
fi

# For each target group ARN
for TARGET_GROUP_ARN in "${TARGET_GROUP_ARNS[@]}"; do
    # Register or deregister based on the operation
    echo "Operation:   $OPERATION"
    echo "Instance:    $INSTANCE_ID"
    echo "TargetGroup: $TARGET_GROUP_ARN"
    response=$(aws elbv2 $OPERATION-targets --target-group-arn $TARGET_GROUP_ARN --targets Id=$INSTANCE_ID --profile $PROFILE --region eu-central-1)
    echo $response
done