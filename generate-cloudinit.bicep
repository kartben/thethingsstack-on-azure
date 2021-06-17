param location string = 'eastus' // resourceGroup().location
param resourcesPrefix string

param adminEmail string
@secure()
param adminPassword string

param networkName string = 'The Things Stack'

@description('The fully qualified domain name of the server hosting the stack. Ex:  \'myttn.francecentral.cloudapp.azure.com\'')
param fqdn string

param redisHost string 
param redisPort int
@secure()
param redisPassword string

param psqlHost string 
param psqlPort int
param psqlLogin string
@secure()
param psqlPassword string

param psqlDatabase string

var scriptName = 'generateCloudInit'
var identityName = 'scratch'
var customRoleName = 'deployment-script-minimum-privilege-for-deployment-principal'
var keyVaultSecretOfficerRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
var keyVaultSecretOfficerRoleDefinitionName = guid(identityName, keyVaultSecretOfficerRoleDefinitionId)

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
    name: identityName
    location: location
}

resource deploymentScriptCustomRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
    name: guid(customRoleName)
    properties: {
      roleName: customRoleName
      description: 'Configure least privilege for the deployment principal in deployment script'
      permissions: [
        {
          actions: [
            'Microsoft.Storage/storageAccounts/*'
            'Microsoft.ContainerInstance/containerGroups/*'
            'Microsoft.Resources/deployments/*'
            'Microsoft.Resources/deploymentScripts/*'
            'Microsoft.Storage/register/action'
            'Microsoft.ContainerInstance/register/action'
          ]
        }
      ]
      assignableScopes: [
        resourceGroup().id
      ]
    }    
}

resource miCustomRoleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: guid(customRoleName, identityName, subscription().id)
    properties: {
        roleDefinitionId: deploymentScriptCustomRole.id
        principalId: mi.properties.principalId
        principalType: 'ServicePrincipal'
    }
}

resource miKeyVaultSecretOfficerRoleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
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
