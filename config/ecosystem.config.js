module.exports = {
    apps : [ 
        Object.assign(
            require('<CONNECTOR_CONFIG_DIR>/ilp-connector.conf.js'),
            { name: 'ilp-connector' }
        )
    ]
};