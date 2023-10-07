# Postman helper

# Use credentials from AWS
Usually you would have to manually transfer credentials from AWS (~/.aws/credentials) to your Postman environment. With this helper, you can run a server and call it from Postman and use Postman's feature to set variables for an environment.

1 Run the server
Run the server with node index.js. By default it runs on port 9999.

2 Set variables in Postman
Run the call "Set AWS credentials" from AC Elasticsearch collection. 

Or create a manual call against http://localhost:9999/{{awsProfile}} and setup the "Tests" tab in Postman like this:
```
var jsonData = JSON.parse(responseBody);

postman.setEnvironmentVariable("awsAccessKey", jsonData.accessKeyId);
postman.setEnvironmentVariable("awsAccessSecret", jsonData.secretAccessKey);
postman.setEnvironmentVariable("awsSessionToken", jsonData.sessionToken);
```
