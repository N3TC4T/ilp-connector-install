module.exports = {
    relation: 'child',
    plugin: 'ilp-plugin-xrp-asym-server',
    assetCode: 'XRP',
    assetScale: 6,
    options: {
      port: 7443,
      xrpServer: 'wss://s2.ripple.com',
      address: process.env.XRP_ADDRESS,
      secret: process.env.XRP_SECRET
    }
  }