Add or remove instances from ALB target groups. This way you can easily restart instances and make sure no services are connected.

# Prerequisites
Create a config file (e.g. statServer.txt) and add the target groups that are relevant to the server you want to restart.

```
targets=(
  "arn:aws:elasticloadbalancing:eu-central-1:ACCOUNTID:targetgroup/XXXX"
)
```

# Usage
Make sure to have the EC2 instance you want to restart at hand (i-xxxxx). Then call ./updateTargetGroups. Select the config file (e.g. statServer.txt), add the instance id (i-xxx) and the operation (add or remove). The instances will be removed from the target - a confirmation will be displayed.

Watch your server logs to make sure traffic is no longer routed to your instance. Then restart. After the instance is back online run the script again (with add operation). 

# Copyright
2022 Mark Poepping, AdmiralCloud AG