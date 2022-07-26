# Connect to AWS EC2
Use this helper to connect to an AWS EC2 instance. Your SSH key is temporarily added to the instance and the access is logged to CloudTrail.

# Usage
First you have to create a temporary session by running the "connect.sh" in the root folder of this project. This session is exported with a profile. The profile is either "mfa" for your default AWS profile or "profileName.mfa" for named profiles, e.g. "live.mfa" for your profile "live".

Call "connectEC2", answer the questions regarding the profile, select the instance you want to connect to and then you get the SSH command to copy and use.


# Prerequisites
## On AWS
### Things you have to do
Upload your public SSH key to AWS IAM. You can create a new one and you can change it any time you like!

Make sure to activate MFA and copy the ARN (you gonna use it in config.js later)

### Things the administrator of your account has to do
The IAM user needs permission to connect to EC2:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2-instance-connect:SendSSHPublicKey",
            "Resource": "arn:aws:ec2:eu-central-1:ACCOUNT-ID:instance/*"
        }
    ]
}
``` 
You can limit access to ressources by replacing * with dedicated instance ids.

### Global access
Create or update .bash_profile (or depending on your setup .zshrc etc) in your home directory (on Mac ~/). 
```
# add this line at the end
alias connectEC2="node PATH-TO-PACKAGE"

# then run (according to your shell) to make sure the changes are activated
source ~/.bash_profile
```

### Config
Create a config.js file in your package's directory with the following content:

```
const config = {
  keyFile: {
    home: '/Users/johndoe', // your home directory
    path: '/.ssh/my-ssh-key' // path to the SSH key (without suffix like .pub)
  }
}

export { config }
```

You can also set the region in this config - if none is set we default to eu-central-1

# TODO
If you want port-forwarding you need to add it manually to the SSH command. In the future we might add this feature.

As an alternative you can setup ~/.ssh/config for a specific instance and set it up with your SSH key.

# Copyright
2022 Mark Poepping, [AdmiralCloud AG](https://www.admiralcloud.com)