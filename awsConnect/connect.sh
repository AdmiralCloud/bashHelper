# unset previous session
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if test -f "${SCRIPTPATH}/config.txt"; then
  source $SCRIPTPATH/config.txt
fi

# PROFILE
read -e -p "Please enter your profile or leave empty for default [${PROFILE}]: " input
PROFILE="${input:-$PROFILE}"

# ARN of MFA
read -e -p "MFA ARN [${MFAARN}]: " input
MFAARN="${input:-$MFAARN}"

read -p "Enter a valid MFA Token: " MFATOKEN

if [ ! -z $PROFILE ]; then
  session=$(aws sts get-session-token --serial-number ${MFAARN} --token-code ${MFATOKEN} --profile ${PROFILE})
  PROFILENAME="${PROFILE}.mfa"
else 
  session=$(aws sts get-session-token --serial-number ${MFAARN} --token-code ${MFATOKEN})
  PROFILENAME="mfa"
fi
# DEBUG SESSION
#echo $session

# set new session
ACCESSKEY="$(echo $session | jq '.Credentials.AccessKeyId' | sed 's/"//g')"
SECRETKEY="$(echo $session | jq '.Credentials.SecretAccessKey' | sed 's/"//g')"
SESSIONTOKEN="$(echo $session | jq '.Credentials.SessionToken' | sed 's/"//g')"

aws configure set aws_access_key_id $ACCESSKEY --profile $PROFILENAME
aws configure set aws_secret_access_key $SECRETKEY --profile $PROFILENAME
aws configure set aws_session_token $SESSIONTOKEN --profile $PROFILENAME

echo "AWS Session for is ready and valid for 12 hours. Use --profile ${PROFILENAME}."