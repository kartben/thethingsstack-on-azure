param redisInternalIpAddress string
param redisFqdn string
param privateDnsZoneName string
param vnetID string

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
    name: '${privateDnsZone.name}/${split(redisFqdn, '.')[0]}'
    properties: {
        aRecords: [
            {
                ipv4Address: redisInternalIpAddress
            }
        ]
        ttl: 3600
    }
}

output privateDnsZoneId string = privateDnsZone.id