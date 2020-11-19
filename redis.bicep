param location string = resourceGroup().location
param redisCacheName string
param subnetId string

resource redisCache 'Microsoft.Cache/Redis@2020-06-01' = {
    name: redisCacheName
    location: location
    properties: {
        enableNonSslPort: false
        sku: {
            name: 'Standard'
            family: 'C'
            capacity: 0 // 250MB
        }
        redisVersion: '6' // The Things Stack requires Redis 5.0 or newer
        publicNetworkAccess: 'Disabled'
    }
}

resource redisCachePrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
    name: '${redisCacheName}-privateendpoint'
    location: location
    properties: {
        privateLinkServiceConnections: [
            {
                name: '${redisCacheName}-privateendpoint'
                properties: {
                    privateLinkServiceId: redisCache.id
                    groupIds: [
                        'redisCache'
                    ]
                }
            }
        ]
        subnet: { 
            id: subnetId
        }
        
    }
}

// Set an output which can be accessed by the module consumer
output redisObject object = redisCache
output redisPrivateIpAddress string = redisCachePrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
output redisHost string = redisCache.properties.hostName
output redisPort int = redisCache.properties.sslPort
output redisKey string = listKeys(redisCache.id, '2019-07-01').primaryKey 
