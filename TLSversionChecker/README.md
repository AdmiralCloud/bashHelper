# TLS Version checker
Reads out the list of subdomains (A + CNAME) from Route53 and then checks TLS version for all subdomains. The result is stored as markup table in a file.

Info:
* _domainkey domains are excluded

# Usage
```
./check.sh DOMAIN AWSPROFILE

e.g.
./check.sh admiralcloud.com default.mfa
```