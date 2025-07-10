# Connect to AWS using MFA/temporary session
If you have MFA enabled for AWS CLI - which is a reasonable security precaution - you need to create a temporary session. You cannot access CLI with your credentials (access key and access secret).

This script makes the temporary session globally available using a named profile. The named profile is either "default" for your default AWS profile or "PROFILENAME.mfa" for named profiles.

# Usage
Run the script "connect.sh", enter your profile, the MFA ARN and a valid MFA token. The script returns the profile you have to use in all subsequent calls. The session is valid for 12 hours by default and is not limited to your current shell/tab.

```
Example:

./connect.sh
Please enter your profile or leave empty for default [default]:

MFA ARN [arn:aws:iam::1234:mfa/janedoe]:
Enter a valid MFA Token: 123456

AWS Session for is ready and valid for 12 hours. Use profile mfa.

// NOW you can access AWS like this
aws s3 ls --profile default.mfa

```

In order to allow calling the script from everywhere, you have to create and alias in your ~/.bash_profile (or depending on your setup .zshrc etc) 
```
# add this line at the end
alias awsConnect="PATH_TO_PACKAGE/connect.sh"


# then run the following command to make sure the changes are activated (according to your shell)
source ~/.bash_profile # source ~/.zshrc if you use zsh
```

# Prerequisites
Create a `config.[profile name].txt` (e.g. config.default.txt for default profile) file in the root directory of this project and add your MFA ARN. This way you don't have to enter it every time you use this script.

```
MFAARN=arn:aws:iam::ACCOUNT-ID:mfa/USERNAME
```

## (Optional) Prerequisites
If you have setup [1password-cli](https://github.com/AdmiralCloud/ac-1password-cli) then `awsConnect/connect.sh` will try to utilise that to retrieve MFA key if needed.
In `config.[profile name].txt` add line
```
MFA1PASWORD=<item-name-or-id>
MFA1PASSWORDPORT=8473
```
* `<item-name-or-id>` - can be retrieved with 1password utility command `op`
* 8473 - is the default port on which ac-1password-cli service runs

# Copyright
2022 Mark Poepping, [AdmiralCloud AG](https://www.admiralcloud.com)