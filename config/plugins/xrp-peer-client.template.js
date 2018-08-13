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
      server: '<PEER_BTP_URL>',
      peerAddress: '<PEER_RIPPLE_ADDRESS>',
      rippledServer: 'wss://s2.ripple.com',
      assetScale: 9,
      address: process.env.XRP_ADDRESS,
      secret: process.env.XRP_SECRET
    }
  }
