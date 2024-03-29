import { readFileSync, existsSync } from 'fs'
import { homedir } from 'os'
import inquirer from 'inquirer'

import { spawn } from 'child_process';

import { EC2Client, DescribeInstancesCommand } from "@aws-sdk/client-ec2"; // ES Modules import
import { EC2InstanceConnectClient, SendSSHPublicKeyCommand } from "@aws-sdk/client-ec2-instance-connect"; // ES Modules import

import { config } from './config.js'
const region = config?.region || 'eu-central-1'

const readSSHConfig = (instance) => {
  const sshConfigFile = `${homedir()}/.ssh/config`

  if (!existsSync(sshConfigFile)) {
    outputDefaultConnect()
    process.exit(0)
  }

  const sshConfig = readFileSync(sshConfigFile)
    .toString('utf8')             // buffer to utf8 string
    .split('\n')                  // to array split by new line
    .filter(f => !!`${f}`.trim()) // discard empty lines
    .reduce((p, v) => {           // transform into array of objects grouped by 'Host'
      v = v.trim()
      if (v.toLowerCase().startsWith('host ')) p.push({ Host: v.split(' ')[1] })
      else if (p.length > 0) {
        if (v.toLowerCase().startsWith('hostname')) {
          const i = v.indexOf(' ')
          p[p.length - 1][v.substring(0, i)] = v.substring(i + 1)
        } else {
          if (!('other' in p[p.length - 1])) p[p.length - 1].other = []
          p[p.length - 1].other.push(v)
        }
      }
      return p
    }, [])
  let configConnect = sshConfig.filter((v) => v.HostName === instance?.hostname)
  if (configConnect.length > 0) configConnect = configConnect[0]
  else configConnect = null

  return configConnect
}

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
  reservation?.Instances.forEach(instance => {
    instances.push({
      value: instance.InstanceId,
      name: instance.Tags.find(item => {
        if (item.Key === 'Name') return item
      })?.Value,
      hostname: instance.PublicDnsName || instance.Tags.find(item => {
        if (item.Key === 'hostname') return item
      })?.Value,
      availabilityZone: instance.Placement?.AvailabilityZone
    })
  })
})

// sort instances by name
instances.sort((a, b) => {
  const nameA = a.name?.toUpperCase(); // ignore upper and lowercase
  const nameB = b.name?.toUpperCase(); // ignore upper and lowercase
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

const choices = ['Yes', 'No']

const sshConfig = readSSHConfig(instance)
if (sshConfig) choices.push('Config')

const connectDirect = {
  type: 'rawlist',
  name: 'connectDirect',
  message: 'Do you want to connect via SSH now? (Yes/No/Config)',
  choices,
}
const connectDirectAnswers = await inquirer.prompt(connectDirect)
let sshCommand = `ssh -i ~${config?.keyFile?.path} ubuntu@${instance?.hostname}`

if (connectDirectAnswers.connectDirect !== 'No') {
  if (connectDirectAnswers.connectDirect === 'Config') sshCommand = `ssh ${sshConfig.Host}`
  console.log('Connecting using ' + sshCommand)
  const args = sshCommand.split(' ').filter(arg => arg !== 'ssh');
  const ssh = spawn('ssh', args, { stdio: 'inherit' })
  ssh.on('close', (code) => {
    if (code !== 0) {
      console.error(`SSH process exited with code ${code}`);
    }
  })
}
else {
  console.log('>>> YOU NOW HAVE 60 SECONDS TO SSH INTO THE INSTANCE')
  console.log(sshCommand)
  if (sshConfig) {
    console.log('>>> OR')
    console.log(`ssh ${sshConfig.Host}\n  HostName ${sshConfig.HostName}\n  ${sshConfig.other.join('\n  ')}`)
  }
}
