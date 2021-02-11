param location string = 'eastus' // resourceGroup().location
param resourcesPrefix string

param adminEmail string
param adminPassword string {
    secure: true
}

param networkName string {
    default: 'The Things Stack'
}
param fqdn string {
    metadata: {
        description: 'The fully qualified domain name of the server hosting the stack. Ex:  \'myttn.francecentral.cloudapp.azure.com\''
    }
}
param redisHost string 
param redisPort int
param redisPassword string {
  secure: true
}

param psqlHost string 
param psqlPort int
param psqlLogin string
param psqlPassword string {
  secure: true
}
param psqlDatabase string

var scriptName = 'generateCloudInit'
var identityName = 'scratch'
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var contributorRoleDefinitionName = guid(identityName, contributorRoleDefinitionId)
var keyVaultSecretOfficerRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
var keyVaultSecretOfficerRoleDefinitionName = guid(identityName, keyVaultSecretOfficerRoleDefinitionId)

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
    name: identityName
    location: location
}

resource miKeyVaultSecretOfficerRoleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: contributorRoleDefinitionName
    properties: {
        roleDefinitionId: contributorRoleDefinitionId
        principalId: mi.properties.principalId
        principalType: 'ServicePrincipal'
    }
}

resource miContributorRoleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: keyVaultSecretOfficerRoleDefinitionName
    properties: {
        roleDefinitionId: keyVaultSecretOfficerRoleDefinitionId
        principalId: mi.properties.principalId
        principalType: 'ServicePrincipal'
    }
}

resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
    name: '${resourcesPrefix}-kv'
    location: location
    properties: {
        tenantId: subscription().tenantId
        sku: { 
            family: 'A'
            name: 'standard'
        }
        enableRbacAuthorization: true
    }
}

resource adminPasswordKeyVaultEntry 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
    name: '${keyvault.name}/ADMIN-PASSWORD'
    properties: {
        value: adminPassword
    }
}

resource redisPasswordKeyVaultEntry 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
    name: '${keyvault.name}/REDIS-PASSWORD'
    properties: {
        value: redisPassword
    }
}

resource psqlPasswordKeyVaultEntry 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
    name: '${keyvault.name}/PSQL-PASSWORD'
    properties: {
        value: psqlPassword
    }
}

resource generateCloudInitDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
    name: scriptName
    location: location
    kind: 'AzureCLI'
    identity: {
        type: 'UserAssigned'
        userAssignedIdentities: {
            '${mi.id}': { }
        }
    }
    properties: {        
        azCliVersion: '2.0.80'
        retentionInterval: 'P1D'
        primaryScriptUri: 'https://raw.githubusercontent.com/kartben/thethingsstack-on-azure/master/generate-cloudinit.sh'
        environmentVariables: [
            {
                name: 'KEYVAULT_NAME'
                value: keyvault.name
            }
            {
                name: 'NETWORK_NAME'
                value: networkName
            }
            {
                name: 'ADMIN_EMAIL'
                value: adminEmail
            }
            {
                name: 'ADMIN_PASSWORD'
                secureValue: adminPassword
            }
            {
                name: 'FQDN'
                value: fqdn
            }
            {
                name: 'REDIS_HOST'
                value: redisHost
            }
            {
                name: 'REDIS_PORT'
                value: string(redisPort)
            }
            {
                name: 'REDIS_PASSWORD'
                secureValue: redisPassword
            }
            {
                name: 'PSQL_HOST'
                value: psqlHost
            }
            {
                name: 'PSQL_PORT'
                value: string(psqlPort)
            }
            {
                name: 'PSQL_LOGIN'
                value: psqlLogin
            }
            {
                name: 'PSQL_PASSWORD'
                secureValue: psqlPassword
            }
            {
                name: 'PSQL_DATABASE'
                value: psqlDatabase
            }
        ]
        supportingScriptUris: [
            'https://raw.githubusercontent.com/kartben/thethingsstack-on-azure/master/cloud-init-template'
        ]
        cleanupPreference: 'OnSuccess'
        timeout: 'PT30M'
    }
}

output cloudInitFileAsBase64 string = generateCloudInitDeploymentScript.properties.outputs.cloudInitFileAsBase64