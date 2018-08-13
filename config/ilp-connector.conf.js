'use strict'

const DEBUG = '*'

const fs = require('fs')
const path = require('path')

function isConfigFile (file) {
  return file.endsWith('conf.js')
}

function getAccountFromConfigFileName (file) {
  return file.slice(0, file.length - 8)
}

function loadNode (confPath, appConfig) {
  console.log(`Loading node config from ${confPath}`)
  const node = require(confPath)

  if (node.address) {
    appConfig.env['CONNECTOR_ILP_ADDRESS'] = node.address
  }

  if (node.backend) {
    appConfig.env['CONNECTOR_BACKEND'] = node.backend
    console.log(` - Backend: ${node.backend}`)
  } else {
    throw new Error('A rates backend must be must be provided for this node')
  }

  if (node.spread) {
    appConfig.env['CONNECTOR_SPREAD'] = '' + node.spread
    console.log(` - Spread: ${node.spread}`)
  } else {
    appConfig.env['CONNECTOR_SPREAD'] = '0'
    console.log(' - No spread provided, defaulting to zero.')
  }

  if (node.apiPort) {
    console.log(` - Api enabled on port ${node.apiPort}`)
    appConfig.env['CONNECTOR_ADMIN_API'] = 'true'
    appConfig.env['CONNECTOR_ADMIN_API_PORT'] = '' + node.apiPort
  }
}

function loadStore (confPath, appConfig) {
  console.log(`Loading store config from ${confPath}`)
  const store = require(confPath)
  if (!store.plugin) {
    throw new Error('No store plugin configured')
  }
  appConfig.env['CONNECTOR_STORE'] = store.plugin
  appConfig.env['CONNECTOR_STORE_CONFIG'] = JSON.stringify(store.config)

  console.log(`- Using ${store.plugin} plugin`)
}

function loadAccounts (peerConfDir, appConfig) {
  console.log(`Loading account config from ${peerConfDir}`)
  const accounts = {}
  const peers = fs.readdirSync(peerConfDir).filter(isConfigFile)
  if (!peers.length) throw new Error('No peer configurations found')
  peers.forEach((file) => {
    const account = getAccountFromConfigFileName(file)
    accounts[account] = require(peerConfDir + '/' + file)
    console.log(`- ${account} (${accounts[account].relation}) : ${accounts[account].plugin}`)
  })
  appConfig.env['CONNECTOR_ACCOUNTS'] = JSON.stringify(accounts)
}

const connectorApp = {
  name: 'connector',
  env: {
    DEBUG,
    CONNECTOR_ENV: 'production'
  },
  script: path.resolve('/srv/ilp-connector/src/index.js')
}

// Ensure XRP config is provided
if (!process.env.XRP_ADDRESS || !process.env.XRP_SECRET) {
  throw new Error('XRP_ADDRESS and XRP_SECRET must be defined')
}

loadNode(path.resolve(__dirname, './node.conf.js'), connectorApp)
loadStore(path.resolve(__dirname, './store.conf.js'), connectorApp)
loadAccounts(path.resolve(__dirname, './peers-enabled'), connectorApp)

if (!fs.existsSync(connectorApp.script)) {
  throw new Error(`Couldn't find ilp-connector start script at ${module.exports.apps[0].script}`)
}

module.exports = connectorApp