param privateDnsZoneName string
param vnetID string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
    name: privateDnsZoneName
    location: 'global'
}

resource privateDnsZoneVNetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
    name: '${privateDnsZoneName}/${privateDnsZoneName}-link'
    location: 'global'
    properties: {
        registrationEnabled: false
        virtualNetwork: {
            id: vnetID
        }
    }
}

resource privateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
    name: '${privateDnsZoneName}/${privateDnsZoneName}-link'
}

output privateDnsZoneId string = privateDnsZone.id