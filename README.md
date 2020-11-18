# Deploying The Things Stack v3 on Azure <!-- omit in toc --> 

This repository contains deployment scripts and instruction to help you deploy your own full-blown LoRaWAN server on Azure.

Skip directly to the [Deployment Instructions](#deployment-instructions) if you want to get your private LoRaWAN backend setup in no time. Read more about the deployed infrastructure in the [dedicated section](#deployment-architecture).

- [Deployment Instructions](#deployment-instructions)
- [Deployment Architecture](#deployment-architecture)
  - [Supporting Resources](#supporting-resources)
    - [Azure Virtual Network](#azure-virtual-network)
    - [Azure KeyVault](#azure-keyvault)
    - [Azure Resource Manager - Deployment Script](#azure-resource-manager---deployment-script)
  - [Main Compute Resources](#main-compute-resources)
    - [Azure VM](#azure-vm)
    - [Azure Cache for Redis](#azure-cache-for-redis)
    - [Azure Database for PostgreSQL](#azure-database-for-postgresql)
- [Pricing Overview](#pricing-overview)

## Deployment Instructions

TODO

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fkartben%2Fthethingsstack-on-azure%2Fmaster%2Fthethingsstack-on-azure.json)
 [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fkartben%2Fthethingsstack-on-azure%2Fmaster%2Fthethingsstack-on-azure.json)

## Deployment Architecture

If you're curious to understand better what resources are effectively deployed when using the ARM template provided in this repository to provision a new Things Stack environment in your Azure Subscription, here's what's happening under the hood!

[TODO: add a diagram]

### Supporting Resources

#### Azure Virtual Network

A dedicated virtual network (VNet) is used to have a common, private, IP address space for the various resources and services needed for powering the stack.

#### Azure KeyVault

Various keys and secrets are used to make sure that your Things Stack deployment is secure, from the credentials needed to access PostgreSQL or Redis instances, to OAuth secrets, to passwords securing tracing and monitoring endpoints.

All these secrets are securely stored in [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/).

#### Azure Resource Manager - Deployment Script

Prior to creating the main virtual machine that will run the core services of The Things Stack, an [ARM Deployment Script](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-script-template) is executed to generate secrets, store them in Azure Key Vault, and preparing the cloud-init script that is launched during the first boot of the VM.

### Main Compute Resources

#### Azure VM

Hosts the actual network server, alongside its various supporting services (ex. Web console, Identity Server, etc.).

Upon creation and during the first boot, the Virtual Machine runs a cloud-init script that installs The Things Stack, and creates the various configuration files needed.

#### Azure Cache for Redis 

Redis is the main data store for the Network Server, Application Server and Join Server. Redis is also used by the Identity Server for caching and can be used by the events system for exchanging events between components.

In order to save you from the burden of managing your own Redis cluster, we are leveraging an Azure Cache for Redis instance. We deploy a Standard C0 instance (256MB of storage), which should be enough to XXX.

For security and performance reasons, the Redis endpoint is made available to the main VM through a private endpoint.

#### Azure Database for PostgreSQL

[As per the documentation](https://thethingsstack.io/reference/components/identity-server/) of The Things Stack, the Identity Server provides the registries that store entities such as applications with their end devices, gateways, users, organizations, OAuth clients and authentication providers. It also manages access control through memberships and API keys. The Identity Server needs to be connected to a PostgreSQL-compatible database so an instance of [Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/services/postgresql/) is deployed to that effect.

For security reasons, the PostgreSQL instance is configured to only allow connections originating from the virtual network where the main VM is running.

## Pricing Overview

Using the default options provided in the ARM template regarding the sizing of the various resources and services, the monthly cost you're looking at is roughly $200. 

You can considerably optimize the cost by looking at [resource reservation](https://docs.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations), as well as making sure that you pick the right size for the various resources based on the scale of your LoRaWAN infrastructure.

![The Things Stack on Azure - Pricing Estimation][pricing-img]


[//]: # (Image References)
[pricing-img]: ./assets/pricing-overview.png "The Things Stack on Azure - Pricing Estimation"
