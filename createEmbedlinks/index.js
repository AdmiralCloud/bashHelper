const axios = require('axios')

/// SECTION WHERE YOU NEED TO UPDATE STUFF

// update with a valid session
const authentication = {
  clientId: 'X',
  device: 'X',
  token: 'X'
}

// channel ID to create new embedlinks for
const channelId = 13857

// playerConfiguration mapping
const mapping = {
  image: 377,
  video: 378
}

const description = 'External player for Mediahub'

// SECTION END - DO NOT EDIT BELOW THIS LINE

const request = async({ method = 'get', path, payload, query }) => {
  const headers = {
    'x-admiralcloud-clientid': authentication.clientId,
    'x-admiralcloud-device': authentication.device,
    'Authorization': `Bearer ${authentication.token}`
  }

  const axiosParams = {
    baseURL: 'https://api.admiralcloud.com/',
    method,
    url: path,
    headers,
  }
  if (payload) axiosParams.data = payload
  if (query) axiosParams.params = query
  
  const response = await axios(axiosParams)
  return response
}


(async () => {

  // fetch mediacontainers for channel
  const { data } = await request({ path: `v5/channel/${channelId}`, query: { withMediaContainers: true }}) // withMediaContainers=true
  const mediacontainers = data?.channels[0].mediaContainers
  const l = mediacontainers.length

  let i = 0
  for (const mc of mediacontainers) {
    i++
    console.log('Request %s/%s | MC %s %s | P %j', i, l, mc.mediaContainerId, mc.type, payload)
    if (!mapping[mc.type]) {
      console.log('MISSING MAPPING MC %s Type %s', mc.mediaContainerId, mc.type)
      continue
    }
    const payload = {
      playerConfigurationId: mapping[mc.type],
      description,
      flag: 2,
      origin: 0,
      checkDuplicate: true
    }
    await request({ method: 'post', path: `v5/embedlink/${mc.mediaContainerId}`, payload })
  }
})()