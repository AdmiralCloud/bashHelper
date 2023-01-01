#!/usr/bin/env zsh

echo "Determine directory"
SCRIPTDIR=`dirname $0`
echo $SCRIPTDIR

declare -A securitygroups    # Declare associative array
source $SCRIPTDIR/config.txt

myIP="$(curl -s ifconfig.me)"
myIP=${myIP}/32
echo "My current IP ${myIP}"

# enhance description with date
description="${description} $(date '+%Y-%m-%d %T')"


## iterate over config
for sg value in ${(kv)securitygroups}; do
    echo "---------------------------------------------------------------"
    IFS=' '; read -rA ports <<< "$value" # str is read into an array as tokens separated by IFS
    env=${ports[1]}

    echo "Updating securitygroup     ${sg}"
    echo "Environment                ${env}"
    echo ""

    json=`aws ec2 describe-security-groups --group-id $sg --query "SecurityGroups[0].IpPermissions" --profile ${env} --region eu-central-1` 
    if [[ ! -z "$json" ]]; 
    then
      echo "${env} - Revoking existing IP/rules"
      aws ec2 revoke-security-group-ingress --cli-input-json "{\"GroupId\": \"$sg\", \"IpPermissions\": $json}" --profile $env --region eu-central-1
    fi


    ports=( "${ports[@]/$env}" )
    echo ""
    for port in "${ports[@]}"; do # access each element of array
      if [[ ! -z "$port" ]]; 
        then
          echo "${env} - Authorizing IP ${myIP} for port ${port}"
          aws ec2 authorize-security-group-ingress --group-id $sg --ip-permissions FromPort=$port,ToPort=$port,IpProtocol=tcp,IpRanges='[{CidrIp='${myIP}',Description="'${description}'"}]' --profile $env --region eu-central-1

        fi
    done
done