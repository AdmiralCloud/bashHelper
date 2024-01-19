# Check Encrytpion Status of S3 buckets
Get the list of S3 buckets from AWS account and checks the encryption status. The result is shown as a markup table in STDOUT and also written into a file.

# Usage
```
./checkEncryption.sh AWS_PROFILE

e.g.
./checkEncryption.sh default.mfa
```

# Ideas
This function can be enhances by defining other properties of an s3 bucket that can be checked.