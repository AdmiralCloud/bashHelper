import { readFileSync } from 'fs'
import inquirer from "inquirer"

import { STSClient, GetSessionTokenCommand, GetCallerIdentityCommand } from "@aws-sdk/client-sts"; // ES Modules import
import { EC2Client, DescribeInstancesCommand } from "@aws-sdk/client-ec2"; // ES Modules import
import { EC2InstanceConnectClient, SendSSHPublicKeyCommand } from "@aws-sdk/client-ec2-instance-connect"; // ES Modules import
import { IAMClient, ListSSHPublicKeysCommand } from "@aws-sdk/client-iam"; // ES Modules import

import { config } from './config.js'
const region = config?.region || 'eu-central-1'

let instances = []

let awsQuestions = [
  {
    type: 'input',
    name: 'awsProfile',
    message: 'The AWS profile to use. Leave empty for default',
    default: config?.awsProfile
  },
  {
    type: 'input',
    name: 'mfaArn',
    message: 'Enter ARN of your MFA device',
    default: config?.mfaArn,
    required: true
  },
  {
    type: 'input',
    name: 'mfaCode',
    message: 'Enter your MFA code',
    required: true
  }
]
const answers = await inquirer.prompt(awsQuestions)

// GET A SESSION
const STS = new STSClient({
  region
})
let command = new GetSessionTokenCommand({
  SerialNumber: answers?.mfaArn,
  TokenCode: answers?.mfaCode
})
let response = await STS.send(command);

let credentials = {
  accessKeyId: response?.Credentials?.AccessKeyId,
  secretAccessKey: response?.Credentials?.SecretAccessKey,
  sessionToken: response?.Credentials?.SessionToken,
  expiration: response?.Credentials?.Expiration,
}
// aws sts get-session-token --serial-number $MFASERIAL --token-code $MFACODE

command = new GetCallerIdentityCommand();
response = await STS.send(command);
console.log('Currently active IAM user: %s', response?.Arn)
const usernameArray = response?.Arn.split('/')
const username = usernameArray[usernameArray.length-1]

// CHECK AGE OF SSH KEY
const iam = new IAMClient({
  region,
  credentials
})
command = new ListSSHPublicKeysCommand({
  UserName: username
})
response = await iam.send(command)
let ageInDays = (new Date().getTime() - new Date(response?.SSHPublicKeys[0]?.UploadDate).getTime())/(86400*1000)
if (ageInDays > 90) {
  console.log('')
  console.log('!!! Please renew your SSH key - it is older than 90 days !!!')
  console.log('')
}
// END OF SESSION ACQUISITION


// FETCH LIST OF RUNNING INSTANCES
const ec2 = new EC2Client({
  region,
  credentials
})
let awsParams = {
  Filters: [{
    Name: "instance-state-name", 
    Values: ["running"]
  }]
}
command = new DescribeInstancesCommand(awsParams);
response = await ec2.send(command)
response?.Reservations.forEach(reservation => {
  instances.push({
    value: reservation.Instances[0].InstanceId,
    name: reservation.Instances[0].Tags.find(item => { 
      if (item.Key === 'Name') return item 
    })?.Value,
    hostname: reservation.Instances[0].PublicDnsName,
    availabilityZone: reservation.Instances[0].Placement?.AvailabilityZone
  })
})

// sort instances by name
instances.sort((a, b) => {
  const nameA = a.name.toUpperCase(); // ignore upper and lowercase
  const nameB = b.name.toUpperCase(); // ignore upper and lowercase
  if (nameA < nameB) {
    return -1
  }
  if (nameA > nameB) {
    return 1
  }
  return 0
})

const selectedValue = await inquirer.prompt({
  type: 'rawlist',
  name: 'instanceId',
  message: 'Please select the instance you want to connect to',
  choices: instances
})
const instance = instances.find(item => {
  if (item.value === selectedValue.instanceId) return item
})
console.log('Connecting to | %s', instance?.name)

// send public key
const ec2conn = new EC2InstanceConnectClient({
  region,
  credentials
})
awsParams = {
  InstanceId: instance?.value,
  AvailabilityZone: instance?.availabilityZone,
  InstanceOSUser: 'ubuntu',
  SSHPublicKey: readFileSync(`${config?.keyFile?.home}${config?.keyFile?.path}.pub`).toString()
}

command = new SendSSHPublicKeyCommand(awsParams);
response = await ec2conn.send(command);

// SET SESSION VARIABLES
process.env.AWS_ACCESS_KEY_ID = credentials.accessKeyId
process.env.AWS_SECRET_ACCESS_KEY = credentials.secretAccessKey
process.env.AWS_SESSION_TOKEN = credentials.sessionToken

console.log('>>> YOU NOW HAVE 60 SECONDS TO SSH INTO THE INSTANCE')
console.log(`ssh -i ~${config?.keyFile?.path} ubuntu@${instance.hostname}`)