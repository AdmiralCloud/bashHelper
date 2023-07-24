# Check (security) headers
This script checks a given list of domains for a given list of headers and their values.

# Run the script
```
./checkHeaders domains.txt headers.txt
```

*domains.txt* is a list of domains (each domain a new line) that should be checked, e.g. 
```
app.admiralcloud.com
api.admiralcloud.com
```

*headers.txt* is a list of headers that should be checked. Each line represents a header and it's value (comma-separated). Make sure the file ends with a new line, otherwise the last header check will be omitted.


Use ANY to check if a header is present at all, regardless of the value. Use NONE to check if a header is absent (expected).

Example:
```
Strict-Transport-Security,max-age=31536000; includeSubDomains; preload
X-Content-Type-Options,nosniff
Content-Security-Policy,ANY
Server,NONE
```


# Prerequisites
## Get a list of domains (A records) from Route53
```
aws route53 list-resource-record-sets --hosted-zone-id ZONE_ID --query "ResourceRecordSets[?Type=='A'].Name" --output text --profile default.mfa | tr "\t" "\n" > domains.txt
```