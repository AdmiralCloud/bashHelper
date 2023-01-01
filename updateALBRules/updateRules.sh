#!/usr/bin/env zsh

echo "Determine directory"
SCRIPTDIR=`dirname $0`
echo $SCRIPTDIR

declare -A rules    # Declare associative array
declare -A targets    # Declare associative array
declare -A patternsActivate
declare -A patternsDeactivate
source $SCRIPTDIR/config.txt

echo "ACTIVATING REDIRECTING TO SELECTED SERVERS FOR THE FOLLOWING RULES AND IPS"
for identifier value in ${(kv)rules}; do
    IFS=' '; read -rA rule <<< "$value" # str is read into an array as tokens separated by IFS
    target=${targets[$identifier]} 

  if [ "$1" = "activate" ]
  then
    pattern=${patternsActivate[$identifier]}
  else
    pattern=${patternsDeactivate[$identifier]}
  fi
  echo "---------------------------------------------------"
  echo "Updating rule for $identifier and IP $ips"
  echo "Rule ARN  : $rule"
  echo "Target ARN: $target"
  echo "Pattern   : $pattern"
  conditions="[{\"Field\": \"path-pattern\", \"Values\": [$pattern] }, {\"Field\": \"source-ip\", \"SourceIpConfig\": { \"Values\": [$ips] }}]"
  echo $conditions
  response=$(aws elbv2 modify-rule \
    --actions Type=forward,TargetGroupArn="$target" \
    --conditions "$conditions"  \
    --rule-arn $rule)
  if [[ $response == *"error"* ]]
  then
    echo $response
  else 
    echo "OK"
  fi
  echo ""
  echo ""

done

