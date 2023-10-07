const express = require('express')
const { fromNodeProviderChain } = require("@aws-sdk/credential-providers")

const app = express()
const port = 9999

app.get('/:profile', async (req, res) => {
    try {
      // Load credentials from the profile
      const profile = req.params.profile
      const credentials = await fromNodeProviderChain({ profile })()
      if (credentials) {
          res.json({
              accessKeyId: credentials.accessKeyId,
              secretAccessKey: credentials.secretAccessKey,
              sessionToken: credentials.sessionToken || null
          })
      } else {
          res.status(500).json({error: "Unable to fetch AWS credentials"})
      }
    } catch (error) {
      res.status(500).json({error: "An error occurred"})
    }
})

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`)
})
