const _ = require('lodash')
const AWS = require('aws-sdk')
const argv = require('minimist')(process.argv.slice(2));

const prefix = _.trim(_.get(argv, 'prefix'))
const profile = _.trim(_.get(argv, 'profile', 'default'))

const creds = new AWS.SharedIniFileCredentials({ profile }) 
AWS.config.credentials = creds;

const sqs = new AWS.SQS({
  region: 'eu-central-1'
})

let awsParams = {
  QueueNamePrefix: prefix,
}
sqs.listQueues(awsParams, (err, result) => {
  if (err) throw new Error(err)
  _.forEach(result.QueueUrls, url => {
    sqs.deleteQueue({ QueueUrl: url }, (err) => {
      if (err) console.log('%s | %j', url, err)
      else console.log('%s | Deleted', url)
    })
  })
})