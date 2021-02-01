# Deploying The Things Stack v3 on Azure <!-- omit in toc -->

This repository contains deployment scripts and instructions to help you deploy your own full-blown LoRaWAN server on Azure cloud.

Skip directly to the [Deployment Instructions](#deployment-instructions) if you want to get your private LoRaWAN backend setup in no time. You can also read more about the deployed infrastructure in the [dedicated section](#deployment-architecture).

- [Deployment Instructions](#deployment-instructions)
- [Deployment Architecture](#deployment-architecture)
  - [Supporting Resources](#supporting-resources)
  - [Main Compute Resources](#main-compute-resources)
- [FAQ](#faq)
  - [How big of a fleet can I connect?](#how-big-of-a-fleet-can-i-connect)
  - [How much is this going to cost me?](#how-much-is-this-going-to-cost-me)

## Deployment Instructions

**Note:** You will need an Azure subscription to host the various cloud resources that will be supporting your Things Stack environment. You can get an Azure free account [here](https://azure.microsoft.com/en-us/free/) to get started.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fkartben%2Fthethingsstack-on-azure%2Fv3.11%2Fthethingsstack-on-azure.json)
 [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fkartben%2Fthethingsstack-on-azure%2Fv3.11%2Fthethingsstack-on-azure.json)
  
- Click on the "**Deploy to Azure**" button below to trigger the deployment process.\
  This will automatically load up the [ARM template](./thethingsstack-on-azure.json) in the Azure portal, and ask you to input the following deployment parameters:

  - **Resource group**: The resource group in which resources will be created. You can create a new one (recommended, as it helps logically group the various resources supporting your future Things Stack instance), or pick an existing one ;
  - **Region**: The region where the resource group will be created, if you are creating a new one ;
  - **Location**: The region where the resources will be deployed. Defaults to the same region as the resource group specified above.

  **<font color="red"><u>IMPORTANT</u></font>**: You should select a location from the list [available here](https://docs.microsoft.com/azure/container-instances/container-instances-region-availability#linux-container-groups). The deployment template is relying on a [deployment script](https://docs.microsoft.com/azure/azure-resource-manager/templates/deployment-script-template?tabs=CLI), an Azure feature that is still in preview at the time of writing. 
  
  - **Prefix**: A short string that will allow you to easily identify the Azure resources associated to your Things Stack deployment ;
  - **Admin email**: The e-mail address of the server admin, used as the "sender" for sending system email ;
  - **Admin password**: The password for user `admin` in the Things Stack console ;
  - **Network name**: The human-friendly name you want to give to your network. This will show up in several places in the web console and emails sent to your users by the system ;
  - **VM size**: The size of the Virtual Machine that will be provisioned to host the Things Stack. Default value should be fine for most deployments (see the [FAQ section below about sizing](#how-big-of-a-fleet-can-i-connect)) ;
  - **VM username**: The username to log into the main VM (ex. over SSH)
  - **VM login method**: Whether you want the user specified just above to login using a password (less secure), or their public SSH key ;
  - **VM password/key**: The password or public SSH key of the VM user, depending on what you pick just above ;
  - **PostgreSQL password**: The password for the PostgreSQL database that will support the Identity Server. Use any (strong) password of your choice here, you may need it if you plan on connecting to the database directly, e.g. for troubleshooting or maintenance. Note: a future version of the deployment template will likely automatically generate a password for you.
  - **PostgreSQL SKU capacity**: The numbers of virtual cores (vCores) for the Azure Database for PostgreSQL Server instance. Default value of 2 should be fine for most deployments (again,see the [FAQ section below about sizing](#how-big-of-a-fleet-can-i-connect)) ; 
  - **DNS label prefix**: You can use this parameter to customise the DNS name that will be given to your publicly accessible Thing Stack services. It is recommended to keep the default value.

- Click on "Next: Review + Create" to... well, review your deployment parameters! If you're happy with them (and the validation checks pass), click ¨Create"

- The provisioning of your Things Stack instance will take 10-20 minutes. I recommend you use this time to go through the [Things Stack documentation](https://thethingsstack.io/getting-started/).

- Once the deployment is complete, you can access the console of your brand new Things Stack instance at the URL indicated in the "Outputs" section of your deployment. It should look something like: `https://ttnv3-myinstance.eastus.cloudapp.azure.com/console`.

  ![The Things Stack on Azure - Outputs on successful deployment][deployment-output]
  
  **Important**: The first time you will open the console, **your browser may complain about an untrusted TLS connection**, which is due to the TLS certificate not being fully created yet. Just refresh the browser and all should be back to normal!

- Enjoy! 🙂

## Deployment Architecture

If you're curious to understand better what resources are effectively deployed when using the ARM template provided in this repository to provision a new Things Stack environment in your Azure Subscription, here's how things look like under the hood!

![The Things Stack on Azure - Deployment Diagram][deployment-diagram]

More specifically, the following resources are deployed in your Azure Subscription.

### Supporting Resources

#### Azure Virtual Network <!-- omit in toc -->

A dedicated virtual network (VNet) is used to have a common, private, IP address space for the various resources and services needed for powering the stack.

#### Azure KeyVault <!-- omit in toc -->

Various keys and secrets are used to make sure that your Things Stack deployment is secure, from the credentials needed to access PostgreSQL or Redis instances, to OAuth secrets, to passwords securing tracing and monitoring endpoints.

All these secrets are securely stored in [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/).

#### Azure Resource Manager - Deployment Script <!-- omit in toc -->

Prior to creating the main virtual machine that will run the core services of The Things Stack, an [ARM Deployment Script](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-script-template) is executed to generate secrets, store them in Azure Key Vault, and preparing the `cloud-init` script that is launched during the first boot of the VM. 

Note: The deployment script is automatically deleted from your subscription 30 minutes after having been provisioned and run successfuly.

### Main Compute Resources

#### Azure VM <!-- omit in toc -->

Hosts the actual network server, alongside its various supporting services (ex. Web console, Identity Server, etc.).

Upon creation and during the first boot, the Virtual Machine runs a cloud-init script that installs The Things Stack, and creates the various configuration files needed.

#### Azure Cache for Redis <!-- omit in toc --> 

Redis is the main data store for the Network Server, Application Server and Join Server. Redis is also used by the Identity Server for caching and can be used by the events system for exchanging events between components.

In order to save you from the burden of managing your own Redis cluster, we are leveraging an Azure Cache for Redis instance. We deploy a Standard C0 instance (256MB of storage), which should be enough to XXX.

For security and performance reasons, the Redis endpoint is made available to the main VM through a private endpoint.

#### Azure Database for PostgreSQL <!-- omit in toc --> 

[As per the documentation](https://thethingsstack.io/reference/components/identity-server/) of The Things Stack, the Identity Server provides the registries that store entities such as applications with their end devices, gateways, users, organizations, OAuth clients and authentication providers. It also manages access control through memberships and API keys. The Identity Server needs to be connected to a PostgreSQL-compatible database so an instance of [Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/services/postgresql/) is deployed to that effect.

For security reasons, the PostgreSQL instance is configured to only allow connections originating from the virtual network where the main VM is running.

## FAQ

### How big of a fleet can I connect?

It probably depends on your use case, your communication patterns, and overall network topology. 

However, and to give you a rough idea, a simulated network made of **50 gateways** and **2000 end nodes** sending a 4 byte uplink every ~5 min (with the corresponding RF packet being forwarded through 1 to 3 gateways), the VM's **CPU usage stays well below 10%**, and the `ttn-lw-stack` process uses **~100MB of RAM**…

### How much is this going to cost me?

Using the default size options provided in the ARM template for the various resources and services, the **monthly cost** you're looking at is roughly **$200**, excluding the cost associated to bandwidth usage. 

You can considerably optimize the cost by looking at [resource reservation](https://docs.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations), as well as making sure that you pick the right size for the various resources based on the scale of your LoRaWAN infrastructure.

![The Things Stack on Azure - Pricing Estimation][pricing-img]

For reference, and at the time of writing (Nov. 2020), LoRaWAN network operators can charge up to a couple dollars per month per device.

[//]: # (Image References)

[deployment-output]: ./assets/deployment-output.png "The Things Stack on Azure - ARM Deployment outputs in the Azure Portal"

[deployment-diagram]: ./assets/deployment-diagram.svg "The Things Stack on Azure - Deployment Diagram"

[pricing-img]: ./assets/pricing-overview.png "The Things Stack on Azure - Pricing Estimation"
