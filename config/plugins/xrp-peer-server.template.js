module.exports = {
    relation: 'peer',
    plugin: 'ilp-plugin-xrp-paychan',
    assetCode: 'XRP',
    assetScale: 9,
    balance: {
      maximum: '1000000000',
      settleThreshold: '-5000000000',
      settleTo: '0'
    },
    options: {
      listener: {
        port: '<LOCAL PORT>',
        secret: '<RANDOM SECRET>'
      },
      rippledServer: 'wss://s2.ripple.com',
      peerAddress: '<XRP LEDGER ADDRESS OF PEER>',
      assetScale: 9,
      address: process.env.XRP_ADDRESS,
      secret: process.env.XRP_SECRET
    }
  }
