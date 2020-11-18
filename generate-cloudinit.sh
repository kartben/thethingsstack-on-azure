#!/bin/bash

function gen_random () {
    openssl rand -hex $1
}

# Generate secrets for various services
HTTP_METRICS_PASSWORD=`gen_random 16`
PPROF_PASSWORD=`gen_random 16`
COOKIE_BLOCK_KEY=`gen_random 32`
COOKIE_HASH_KEY=`gen_random 64`
CONSOLE_OAUTH_CLIENT_SECRET=`gen_random 32`
DEVICE_CLAIMING_OAUTH_CLIENT_SECRET=`gen_random 32`

# Store secrets in keyvault
az keyvault secret set --name HTTP-METRICS-PASSWORD --vault-name $KEYVAULT_NAME --value $HTTP_METRICS_PASSWORD -o none
az keyvault secret set --name PPROF-PASSWORD --vault-name $KEYVAULT_NAME --value $PPROF_PASSWORD -o none
az keyvault secret set --name COOKIE-BLOCK-KEY --vault-name $KEYVAULT_NAME --value $COOKIE_BLOCK_KEY -o none
az keyvault secret set --name COOKIE-HASH-KEY --vault-name $KEYVAULT_NAME --value $COOKIE_HASH_KEY -o none
az keyvault secret set --name CONSOLE-OAUTH-CLIENT-SECRET --vault-name $KEYVAULT_NAME --value $CONSOLE_OAUTH_CLIENT_SECRET -o none
az keyvault secret set --name DEVICE-CLAIMING-OAUTH-CLIENT-SECRET --vault-name $KEYVAULT_NAME --value $DEVICE_CLAIMING_OAUTH_CLIENT_SECRET -o none

sed "s/%%KEYVAULT_NAME%%/$KEYVAULT_NAME/g; \
     s/%%ADMIN_EMAIL%%/$ADMIN_EMAIL/g; \
     s/%%FQDN%%/$FQDN/g; \
     s/%%NETWORK_NAME%%/$NETWORK_NAME/g; \
     s/%%REDIS_HOST%%/$REDIS_HOST/g; s/%%REDIS_PORT%%/$REDIS_PORT/g; \
     s/%%PSQL_HOST%%/$PSQL_HOST/g; s/%%PSQL_PORT%%/$PSQL_PORT/g; s/%%PSQL_LOGIN%%/$PSQL_LOGIN/g; s/%%PSQL_DATABASE%%/$PSQL_DATABASE/g; \
     " cloud-init-template | base64 | tr -d '\n\r' |  awk '{printf "{\"cloudInitFileAsBase64\": \"%s\"}", $1}' > $AZ_SCRIPTS_OUTPUT_PATH
