param location string = resourceGroup().location
param redisCacheName string
param subnetId string
param vnetID string

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

var privateDnsZoneName = 'privatelink.redis.cache.windows.net'
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
    name: privateDnsZoneName
    location: 'global'
}

resource privateDnsZoneVNetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
    name: '${privateDnsZone.name}/${uniqueString(vnetID)}'
    location: 'global'
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vnetID
        }
    }
}

resource privateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
    name: '${privateDnsZone.name}/${redisCache.name}'
    properties: {
        aRecords: [
            {
                ipv4Address: redisCachePrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
            }
        ]
        ttl: 3600
    }
}

output redisHost string = redisCache.properties.hostName
output redisPort int = redisCache.properties.sslPort
output redisKey string = listKeys(redisCache.id, '2019-07-01').primaryKey 
