This is a little helper that compares 2 HTTP responses for difference in properties. It is helpful when updating API versions.

# Usage
Copy the required (authenticated) call from your browser's inspector ("Copy as NodeJS fetch") and insert this into lines 23/26. The run with ***node index.js**

Example
```
// vanilla version
const u1 = await fetch("https://api.admiralcloud.com/v2/user/me")

// updated with your actual call
const u1 = await fetch("https://iam.admiralcloud.com/v1/user/domain", {
  "headers": {
    "accept": "application/json, text/plain, */*",
    "accept-language": "de-DE,de;q=0.6",
    "authorization": "Bearer XXXXX",
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-site",
    "sec-gpc": "1",
    "x-admiralcloud-clientid": "8d09356a-042f-4d4a-9c6f-935329000969",
    "x-admiralcloud-device": "XXXXX",
    "Referer": "https://app.admiralcloud.com/",
    "Referrer-Policy": "strict-origin-when-cross-origin"
  },
  "body": null,
  "method": "GET"
});

```

Do the samewith u2 variable. And then run the script. The console with output information on difference in keys, values and types.
