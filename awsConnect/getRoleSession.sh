#!/bin/bash

# This script must be provided at a global location (e.g. /opt/scripts) on non-EC2 instances.
# 

# ./getRoleSession ROLENAME PROFILE
# e.g. ./getRoleSession.sh ac-stat-instance-role dev
# The use the script in ~/.aws/config for a given profile to retrieve and manage credentials
# [profile ac-api-instance-role]
# credential_process = ABS_PATH/getRoleSession.sh  "ac-api-instance-role" "dev"

# AWS SDK as well as AWS CLI will handle session expiration/key rotation automatically
# please make sure to export AWS_PROFILE=role so the service or API can use the profile

# It is also vital, that the script does not return anything else but the given JSON. 
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sourcing-external.html

ROLE=$1
PROFILE="${2:-default}"
DURATION="${3:-3600}"

# fetch the accountid
identity=$(aws sts get-caller-identity --profile ${PROFILE})
ACCOUNTID="$(echo $identity | jq '.Account' | sed 's/"//g')"

PROFILENAME="${ROLE}.temp"
session=$(aws sts assume-role --role-arn arn:aws:iam::${ACCOUNTID}:role/${ROLE} --role-session-name ${PROFILENAME} --profile ${PROFILE} --duration ${DURATION})

# set new session
ACCESSKEY="$(echo $session | jq '.Credentials.AccessKeyId' | sed 's/"//g')"
SECRETKEY="$(echo $session | jq '.Credentials.SecretAccessKey' | sed 's/"//g')"
SESSIONTOKEN="$(echo $session | jq '.Credentials.SessionToken' | sed 's/"//g')"
EXPIRATION="$(echo $session | jq '.Credentials.Expiration' | sed 's/"//g')"

# return JSON according to LINK above
cat << EOF
{
  "Version": 1,
  "AccessKeyId": "$ACCESSKEY",
  "SecretAccessKey": "$SECRETKEY",
  "SessionToken": "$SESSIONTOKEN",
  "Expiration": "$EXPIRATION"
}
EOF