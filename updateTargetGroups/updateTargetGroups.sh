# Update target groups for a given collection (e.g. Bullv1, OGS, Stat)
# Remove instance X from TG
# After successful removal a server can be restarted
# Also allow adding services again

#!/usr/bin/env bash

read -p "Enter config [statServer]: " configFile
configFile=${configFile:-statServer}
source ./$configFile.txt
echo "Using configuration $configFile"
echo ""

read -p "Please enter the instance to remove from targets" instance
#instance=${instance:-"i-xxxxxx"}
echo "Using instance $instance"
echo ""

response=$(aws ec2 describe-instances --instance-ids $instance \
  --filters Name=tag-key,Values=Name \
  --query 'Reservations[*].Instances[*].{Instance:InstanceId,Name:Tags[?Key==`Name`]|[0].Value}' --output text
)
echo "INSTANCE"
echo $response
echo ""

echo "OPERATION"
read -p "Add or remove? " op
op=${op:-add}

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
  exit
fi

if [[ $op = "remove" ]]
then
  echo "Removing instance from targets"
  for target in "${targets[@]}"; do
    echo "Remove $instance from $target"
    response=$(aws elbv2 deregister-targets --target-group-arn=$target --targets Id=$instance)
    if [[ $response == *"error"* ]]
    then
      echo $response
    else 
      echo "Removal successful"
    fi
    echo ""
  done
else
  echo "Adding instance to targets"
  for target in "${targets[@]}"; do
    echo "Adding $instance to $target"
    response=$(aws elbv2 register-targets --target-group-arn=$target --targets Id=$instance)
    if [[ $response == *"error"* ]]
    then
      echo $response
    else 
      echo "Adding successful"
    fi
    echo ""
  done
fi








