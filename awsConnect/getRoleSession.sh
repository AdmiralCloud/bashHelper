#
# use a cron job to fetch credentials for an IAM role
# call this script with argument of the role
# ./getRoleSession ROLENAME PROFILE
# e.g. ./getRoleSession.sh ac-stat-instance-role dev

# unset previous session
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

#
#ARG1=${1:-foo}
PROFILE="${2:-default}"
echo $PROFILE


# fetch the accountid
identity=$(aws sts get-caller-identity --profile ${PROFILE})
ACCOUNTID="$(echo $identity | jq '.Account' | sed 's/"//g')"

ROLE=$1
PROFILENAME="${ROLE}.temp"
session=$(aws sts assume-role --role-arn arn:aws:iam::${ACCOUNTID}:role/${ROLE} --role-session-name ${PROFILENAME} --profile ${PROFILE})

# DEBUG SESSION
#echo $session

# set new session
ACCESSKEY="$(echo $session | jq '.Credentials.AccessKeyId' | sed 's/"//g')"
SECRETKEY="$(echo $session | jq '.Credentials.SecretAccessKey' | sed 's/"//g')"
SESSIONTOKEN="$(echo $session | jq '.Credentials.SessionToken' | sed 's/"//g')"

aws configure set aws_access_key_id $ACCESSKEY --profile $PROFILENAME 2> /dev/null
aws configure set aws_secret_access_key $SECRETKEY --profile $PROFILENAME 2> /dev/null
aws configure set aws_session_token $SESSIONTOKEN --profile $PROFILENAME 2> /dev/null

echo "AWS Session for is ready and valid for 1 hour. Use --profile ${PROFILENAME}."