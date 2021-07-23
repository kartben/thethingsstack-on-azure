// Location for all resources.
param location string = resourceGroup().location

// Global resource prefix
@maxLength(6)
@description('Prefix to use when creating Azure resources')
param prefix string = 'ttnv3'
var resourcesPrefix = '${prefix}${uniqueString(resourceGroup().id)}'

@description('E-mail address of the administrator')
param adminEmail string

@secure()
@description('Password for the \'admin\' user in the Things Stack console')
param adminPassword string

@description('The name to give to your Things Stack network')
param networkName string = 'The Things Stack on Azure 🚀'

// The size of the VM.
@description('VM Size. For available virtual machine sizes, see https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/2019-07-01/virtualmachines#HardwareProfile')
param vmSize string = 'Standard_B2s'

// Username for the Virtual Machine.
@description('VM User name. Used to log into the main virtual machine')
param vmUserName string

// Type of authentication to use on the Virtual Machine. SSH key is recommended.
@allowed([
    'sshPublicKey'
    'password'
])
@description('VM Authentication type (SSH Public key or password)')
param vmAuthenticationType string = 'password'

// SSH Key or password for the Virtual Machine. SSH key is recommended.
@secure()
param vmAdminPasswordOrKey string

var psqlLogin = 'ttn_pguser'

@secure()
@description('PostgreSQL database administrator password')
param psqlPassword string

var psqlDatabaseName = 'ttn_lorawan'

@allowed([
    2
    4
    8
    16
    32
    64
])
@description('Azure database for PostgreSQL compute capacity (# of vCores)')
param psqlSkuCapacity int = 2

// Unique DNS Name for the Public IP used to access the Virtual Machine.
@description('Unique DNS Name for the Public IP used to access the main virtual machine')
param dnsLabelPrefix string = '${prefix}-stack-${uniqueString(resourceGroup().id)}'

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
            {
                name: 'TTN_GatewayServerMQTTS'
                properties: {
                    priority: 2300
                    protocol: 'Tcp'
                    access: 'Allow'
                    direction: 'Inbound'
                    sourceAddressPrefix: '*'
                    sourcePortRange: '*'
                    destinationAddressPrefix: '*'
                    destinationPortRange: '8882'
                }
            }        
            {
                name: 'TTN_AppServerMQTTS'
                properties: {
                    priority: 2400
                    protocol: 'Tcp'
                    access: 'Allow'
                    direction: 'Inbound'
                    sourceAddressPrefix: '*'
                    sourcePortRange: '*'
                    destinationAddressPrefix: '*'
                    destinationPortRange: '8883'
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

var psqlResourceName = '${resourcesPrefix}-psql'
module postgreSQLDeployment './postgresql.bicep' = {
    name: 'postgreSQLDeployment'
    params: {
        psqlResourceName: psqlResourceName
        subnetId: subnetRef
        vnetID: vnet.id
        psqlSkuCapacity: psqlSkuCapacity
        psqlLogin: psqlLogin
        psqlPassword: psqlPassword
        psqlDatabaseName: psqlDatabaseName
    }
}

// module redisDeployment './redis.bicep' = {
//     name: 'redisDeployment'
//     params: {
//         redisCacheName: '${resourcesPrefix}-redis'
//         subnetId: subnetRef
//         vnetID: vnet.id
//     }
// }

module generateCloudInitTask './generate-cloudinit.bicep' = {
    name: 'generateCloudInitTask'
    params: {
        location: location
        resourcesPrefix: resourcesPrefix
        adminEmail: adminEmail
        adminPassword: adminPassword
        networkName: networkName
        fqdn: publicIP.properties.dnsSettings.fqdn
        redisHost: 'redis_dummy_host'
        redisPort: 1234
        redisPassword: 'redis_dummy_password'
        psqlHost: postgreSQLDeployment.outputs.fqdn
        psqlPort: 5432
        psqlLogin: uriComponent('${psqlLogin}@${psqlResourceName}')
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
