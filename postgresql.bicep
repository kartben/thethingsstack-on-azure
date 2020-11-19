param location string = resourceGroup().location
param subnetId string
param vnetID string

param psqlResourceName string
param psqlSkuCapacity int

param psqlLogin string
param psqlPassword string {
  secure: true
}
param psqlDatabaseName string

resource postgreSQL 'Microsoft.DBForPostgreSQL/servers@2017-12-01' = {
  name: psqlResourceName
  location: location
  properties: {
      administratorLogin: psqlLogin
      administratorLoginPassword: psqlPassword
      createMode: 'Default'
      sslEnforcement: 'Enabled'
      publicNetworkAccess: 'Enabled'
      version: '10'
  }
  sku: {
      name: 'GP_Gen5_2'
      tier: 'GeneralPurpose' // TODO: Basic tier is probably fine (and cheaper!) for small network deployments.
      family: 'Gen5'
      capacity: psqlSkuCapacity
  }
}

resource postgreSQLVNetRule 'Microsoft.DBForPostgreSQL/servers/virtualNetworkRules@2017-12-01' = {
  name: '${postgreSQL.name}/vnet'    
  properties: {
      virtualNetworkSubnetId: subnetId
      ignoreMissingVnetServiceEndpoint: true
  }
}

resource postgreSQLDatabase 'Microsoft.DBForPostgreSQL/servers/databases@2017-12-01-preview' = {
  name: '${postgreSQL.name}/${psqlDatabaseName}'
}

resource postgreSQLPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: '${psqlResourceName}-privateendpoint'
  location: location
  properties: {
      privateLinkServiceConnections: [
          {
              name: '${psqlResourceName}-privateendpoint'
              properties: {
                  privateLinkServiceId: postgreSQL.id
                  groupIds: [
                      'postgresqlServer'
                  ]
              }
          }
      ]
      subnet: { 
          id: subnetId
      }
      
  }
}

var privateDnsZoneName = 'privatelink.postgres.database.azure.com'
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
    name: '${privateDnsZone.name}/${psqlResourceName}'
    properties: {
        aRecords: [
            {
                ipv4Address: postgreSQLPrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
            }
        ]
        ttl: 3600
    }
}

output fqdn string = postgreSQL.properties.fullyQualifiedDomainName