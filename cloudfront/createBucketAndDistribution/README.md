# Create S3 Bucket and Cloudfront Distribution
This script creates or updates S3 buckets for client apps, then creates or updates the related Cloudfront distribution and finally updates the S3 bucket with the proper policy if the distribution is created.

By default, the profile "default.mfa" is used. Make sure to copy the file "placeholder_config_template.json" to placeholder_config.json and adjust it as needed. You can also use different names and define them using CLI parameter.

# Usage
```
// SIMPLE (with default values)
./createS3AndCF.sh -b BUCKET_NAME

// WITH PROFILE
./createS3AndCF.sh -b BUCKET_NAME --profile PROFILE
```

## Available options:
* -b|--bucket BUCKET_NAME
* --profile PROFILE
* --region REGION -> defaults to eu-central-1
* --s3-config-template TEMPLATE -> template file
* --cloudfront-config-template TEMPLATE -> template file
* --placeholder-config FILE -> Placeholder config file (default: placeholder_config.json)"

# Helpers
Use getS3Config and getCFConfig to retrieve configs and update the templates if necessary. 