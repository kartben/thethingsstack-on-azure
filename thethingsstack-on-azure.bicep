// Location for all resources.
param location string = resourceGroup().location

// Global resource prefix
param prefix string {
    default: 'ttnv3'
    maxLength: 6
    metadata: {
        description: 'Prefix to use when creating Azure resources'
    }
}
var resourcesPrefix = '${prefix}${uniqueString(resourceGroup().id)}'

param adminEmail string {
    metadata: {
        description: 'E-mail address of the administrator'
    }
}

param adminPassword string {
    secure: true
    metadata: {
        description: 'Password for the \'admin\' user in the Things Stack console'
    }
}

param networkName string {
    default: 'The Things Stack on Azure 🚀'
    metadata: {
        description: 'The name to give to your Things Stack network'
    }
}

// The size of the VM.
param vmSize string {
    default: 'Standard_B2s'
    metadata: {
        description: 'VM Size. For available virtual machine sizes, see https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/2019-07-01/virtualmachines#HardwareProfile'
    }
}

// Username for the Virtual Machine.
param vmUserName string {
    metadata: {
        description: 'VM User name. Used to log into the main virtual machine'
    }
}

// Type of authentication to use on the Virtual Machine. SSH key is recommended.
param vmAuthenticationType string {
    default: 'password'
    allowed: [
        'sshPublicKey'
        'password'
    ]
    metadata: {
        description: 'VM Authentication type (SSH Public key or password)'
    }
}

// SSH Key or password for the Virtual Machine. SSH key is recommended.
param vmAdminPasswordOrKey string {
    secure: true
}

var psqlLogin = 'ttn_pguser'

param psqlPassword string  {
    secure: true
    metadata: {
        description: 'PostgreSQL database administrator password'
    }
}

var psqlDatabaseName = 'ttn_lorawan'

param psqlSkuCapacity int {
    default: 2
    allowed: [
        2
        4
        8
        16
        32
        64
    ]        
    metadata: {
        description: 'Azure database for PostgreSQL compute capacity (# of vCores)'
    }        
}        

// Unique DNS Name for the Public IP used to access the Virtual Machine.
param dnsLabelPrefix string {
    default: '${prefix}-stack-${uniqueString(resourceGroup().id)}'
    metadata: {
        description: 'Unique DNS Name for the Public IP used to access the main virtual machine'
    }
}

var vmName = '${resourcesPrefix}-vm'
var publicIPAddressName = '${vmName}-publicip'
var networkInterfaceName = '${vmName}-networkif'
var virtualNetworkName = '${resourcesPrefix}-vnet'
var subnetName = '${resourcesPrefix}-subnet'
var subnetRef = '${vnet.id}/subnets/${subnetName}'
var networkSecurityGroupName = '${resourcesPrefix}-secgroup'
var osDiskType = 'Standard_LRS'
var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'
var linuxConfiguration = {
    disablePasswordAuthentication: true
    ssh: {
        publicKeys: [
            {
                path: '/home/${vmUserName}/.ssh/authorized_keys'
                keyData: vmAdminPasswordOrKey
            }
        ]
    }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
    name: networkInterfaceName
    location: location
    properties: {
        ipConfigurations: [
            {
                name: 'ipconfig1'
                properties: {
                    subnet: {
                        id: subnetRef
                    }
                    privateIPAllocationMethod: 'Dynamic'
                    publicIPAddress: {
                        id: publicIP.id
                    }
                }
            }
        ]
        networkSecurityGroup: {
            id: nsg.id
        }
    }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
    name: networkSecurityGroupName
    location: location
    properties: {
        securityRules: [
            {
                name: 'SSH'
                properties: {
                    priority: 1000
                    protocol: 'Tcp'
                    access: 'Allow'
                    direction: 'Inbound'
                    sourceAddressPrefix: '*'
                    sourcePortRange: '*'
                    destinationAddressPrefix: '*'
                    destinationPortRange: '22'
                }
            }
            {
                name: 'HTTP'
                properties: {
                    priority: 2000
                    protocol: 'Tcp'
                    access: 'Allow'
                    direction: 'Inbound'
                    sourceAddressPrefix: '*'
                    sourcePortRange: '*'
                    destinationAddressPrefix: '*'
                    destinationPortRange: '80'
                }
            }
            {
                name: 'HTTPS'
                properties: {
                    priority: 2100
                    protocol: 'Tcp'
                    access: 'Allow'
                    direction: 'Inbound'
                    sourceAddressPrefix: '*'
                    sourcePortRange: '*'
                    destinationAddressPrefix: '*'
                    destinationPortRange: '443'
                }
            }
            {
                name: 'TTN_Router'
                properties: {
                    priority: 2200
                    protocol: 'Udp'
                    access: 'Allow'
                    direction: 'Inbound'
                    sourceAddressPrefix: '*'
                    sourcePortRange: '*'
                    destinationAddressPrefix: '*'
                    destinationPortRange: '1700'
                }
            }        
        ]
    }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
    name: virtualNetworkName
    location: location
    properties: {
        addressSpace: {
            addressPrefixes: [
                addressPrefix
            ]
        }
        subnets: [
            {
                name: subnetName
                properties: {
                    addressPrefix: subnetAddressPrefix
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Enabled'
                    serviceEndpoints: [
                        { 
                            service: 'Microsoft.SQL'
                        }
                    ]
                }
            }
        ]
    }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
    name: publicIPAddressName
    location: location
    properties: {
        publicIPAllocationMethod: 'Dynamic'
        publicIPAddressVersion: 'IPv4'
        dnsSettings: {
            domainNameLabel: dnsLabelPrefix
        }
        idleTimeoutInMinutes: 4
    }
    sku: {
        name: 'Basic'
    }
}

resource postgreSQL 'Microsoft.DBForPostgreSQL/servers@2017-12-01' = {
    name: '${resourcesPrefix}-psql'
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
        virtualNetworkSubnetId: subnetRef
        ignoreMissingVnetServiceEndpoint: true
    }
}

resource postgreSQLDatabase 'Microsoft.DBForPostgreSQL/servers/databases@2017-12-01-preview' = {
    name: '${postgreSQL.name}/${psqlDatabaseName}'
}

module redisDeployment './redis.bicep' = {
    name: 'redisDeployment'
    params: {
        redisCacheName: '${resourcesPrefix}-redis'
        subnetId: subnetRef
    }
}

module privatednszone './privatednszone.bicep' = {
    name: 'privatednszoneDeploy'
    params: {
        redisInternalIpAddress: redisDeployment.outputs.redisPrivateIpAddress
        redisFqdn: redisDeployment.outputs.redisHost
        privateDnsZoneName: 'privatelink.redis.cache.windows.net'
        vnetID: vnet.id
    }
}

module generateCloudInitTask './generate-cloudinit.bicep' = {
    name: 'generateCloudInitTask'
    params: {
        location: location
        resourcesPrefix: resourcesPrefix
        adminEmail: adminEmail
        adminPassword: adminPassword
        networkName: networkName
        fqdn: publicIP.properties.dnsSettings.fqdn
        redisHost: redisDeployment.outputs.redisHost
        redisPort: redisDeployment.outputs.redisPort
        redisPassword: redisDeployment.outputs.redisKey
        psqlHost: postgreSQL.properties.fullyQualifiedDomainName
        psqlPort: 5432
        psqlLogin: uriComponent('${psqlLogin}@${postgreSQL.name}')
        psqlPassword: uriComponent(psqlPassword)
        psqlDatabase: psqlDatabaseName
    }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
    name: vmName
    location: location
    properties: {
        hardwareProfile: {
            vmSize: vmSize
        }
        storageProfile: {
            osDisk: {
                createOption: 'FromImage'
                managedDisk: {
                    storageAccountType: osDiskType
                }
            }
            imageReference: {
                publisher: 'Canonical'
                offer: 'UbuntuServer'
                sku: '18.04-LTS'
                version: 'latest'
            }
        }
        networkProfile: {
            networkInterfaces: [
                {
                    id: nic.id
                }
            ]
        }
        osProfile: {
            computerName: vmName
            adminUsername: vmUserName
            adminPassword: vmAdminPasswordOrKey
            linuxConfiguration: any(vmAuthenticationType == 'password' ? null : linuxConfiguration) // TODO: workaround for https://github.com/Azure/bicep/issues/449
            customData: generateCloudInitTask.outputs.cloudInitFileAsBase64
        }
    }
    identity: {
        type: 'SystemAssigned' // assign a system identity to the VM to later grant it e.g. keyvault read permission
    }
}

// assign VM the "Key Vault Secret User" permission
var keyVaultReaderRole = resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
resource keyVaultReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: guid(vmName, keyVaultReaderRole)
    properties: {
        principalId: vm.identity.principalId
        roleDefinitionId: keyVaultReaderRole
    }
}

// assign VM the "Virtual Machine Contributor" role (used for tagging the VM resource to indicate its current status in the portal)
var vmContributorRole = resourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
resource vmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: guid(vmName, vmContributorRole)
    properties: {
        principalId: vm.identity.principalId
        roleDefinitionId: vmContributorRole
    }
}

output sshCommand string = 'ssh ${vmUserName}@${publicIP.properties.dnsSettings.fqdn}'
output ttnConsoleUrl string = 'https://${publicIP.properties.dnsSettings.fqdn}/console'