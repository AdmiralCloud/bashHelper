import { readFileSync } from 'fs'
import inquirer from "inquirer"

import { EC2Client, DescribeInstancesCommand } from "@aws-sdk/client-ec2"; // ES Modules import
import { EC2InstanceConnectClient, SendSSHPublicKeyCommand } from "@aws-sdk/client-ec2-instance-connect"; // ES Modules import

import { config } from './config.js'
const region = config?.region || 'eu-central-1'

const awsQuestions = [
  {
    type: 'input',
    name: 'awsProfile',
    message: 'The AWS MFA profile to use',
    default: 'default'
  }
]
const answers = await inquirer.prompt(awsQuestions)
if (answers?.awsProfile && !answers.awsProfile.toLowerCase().endsWith('.mfa')) {
  answers.awsProfile += '.mfa'
}
process.env.AWS_PROFILE = answers?.awsProfile

const instances = []

// FETCH LIST OF RUNNING INSTANCES
const ec2 = new EC2Client({
  region
})
let awsParams = {
  Filters: [{
    Name: "instance-state-name", 
    Values: ["running"]
  }]
}
let command = new DescribeInstancesCommand(awsParams);
let response = await ec2.send(command)
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
  region
})
awsParams = {
  InstanceId: instance?.value,
  AvailabilityZone: instance?.availabilityZone,
  InstanceOSUser: 'ubuntu',
  SSHPublicKey: readFileSync(`${config?.keyFile?.home}${config?.keyFile?.path}.pub`).toString()
}

command = new SendSSHPublicKeyCommand(awsParams);
response = await ec2conn.send(command);


console.log('>>> YOU NOW HAVE 60 SECONDS TO SSH INTO THE INSTANCE')
console.log(`ssh -i ~${config?.keyFile?.path} ubuntu@${instance.hostname}`)
