Use this bash script to create a key and CSR for a given domain:

# Process
## Create config file
Please createa file *csr_config.conf* with the following content:

```
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = DE
ST = state
L = city
O = organization
OU = org unit
CN = DOMAIN_PLACEHOLDER
emailAddress = email
```

**Do not change DOMAIN_PLACEHOLDER!**

## Run the script
After you have created the config file, you can simply run the bash script *createCSR.sh*, answer the questions and everything else will work automatically. 

The key, the CSR and the zipped CSR will be created.

# Info
Copyright AdmiralCloud AG, Mark Poepping