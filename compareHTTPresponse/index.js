const axios = require('axios')

const fetch = async(url, options) => {
  try {
    const axiosParams = {
      url
    }
    Object.assign(axiosParams, options)
    console.log('Fetching: %s', url)
    const response = await axios(axiosParams)
    return response?.data
  } catch (error) {
    console.error(error?.response?.status, error?.response?.data)
    process.exit(0)
  }
}




// fetch URL 1
const start = async() => {
  // PASTE/replace from "Copy as NODEJS fetch"
  const u1 = await fetch("https://api.admiralcloud.com")

  // PASTE/replace from "Copy as NODEJS fetch"
  const u2 = await fetch("https://iam.admiralcloud.com")

  
  const keys1 = Object.keys(u1)
  const keys2 = Object.keys(u2)
  let difference = keys1.filter(key => !keys2.includes(key)).concat(keys2.filter(key => !keys1.includes(key)))

  console.log('-'.repeat(80))
  console.log('Difference in properties: %j', difference)
  console.log('-'.repeat(80))
  for (key of difference) {
    console.log('%s | %j | %j', key, u1[key], u2[key])
    console.log('-'.repeat(80))
  }

  // check type differences for identical fields
  let intersection = keys1.filter(key => keys2.includes(key))
  for (key of intersection) {
    if (typeof u1[key] !== typeof u2[key]) {
      console.log('Type difference in property: %s', key)
      console.log('U1 %s: %j', typeof u1[key], u1[key])
      console.log('U2 %s: %j', typeof u2[key], u2[key])
      console.log('-'.repeat(80))
    }
  }
  process.exit(0)
}

start()
