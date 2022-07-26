# Connect to AWS using MFA/temporary session
If you have MFA enabled for AWS CLI - which is a reasonable security precaution - you need to create a temporary session. You cannot access CLI with your credentials (access key and access secret).

This script makes the temporary session globally available using a named profile. The named profile is either "mfa" for your default AWS profile or "PROFILENAME.mfa" for named profiles.

# Usage
Run the script "connect.sh", enter your profile, the MFA ARN and a valid MFA token. The script returns the profile you have to use in all subsequent calls. The session is valid for 12 hours by default and is not limited to your current shell/tab.

```
Example:

./connect.sh
Please enter your profile or leave empty for default []:

MFA ARN [arn:aws:iam::1234:mfa/janedoe]:
Enter a valid MFA Token: 123456

AWS Session for is ready and valid for 12 hours. Use profile mfa.

// NOW you can access AWS like this
aws s3 ls --profile mfa

```

# Prerequisites
Create a config file and add your MFA ARN. This way you don't have to enter it every time you use this script.

# Copyright
2022 Mark Poepping, [AdmiralCloud AG](https://www.admiralcloud.com)