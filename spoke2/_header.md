## Spoke_02 Resources Group
The Spoke02 resource group establishes a secure Azure network architecture, including virtual networks, subnets, security groups, virtual machines, and storage solutions for enhanced resource management and connectivity.

## 🚀 Configuration Overview

#### 🏗️ Resource Group
- Sets up a logical container for Azure resources, defining its name and location.

#### 🌐 Virtual Network Deployment
- Creates a virtual network, specifying its address space and associating it with the resource group.

#### Subnet
- Establishes subnets within the virtual network, defining their address prefixes.

#### 🛡️ Network Security Group (NSG) Configuration
- Creates an NSG to manage inbound and outbound traffic with specified security rules.

#### 🔗 NSG Association with Subnets
- Links the NSG to the created subnets to enforce security rules.

#### 🌍 Public IP Allocation
- Assigns a static public IP for the Application Gateway, ensuring external access.

#### 🚪 Application Gateway Setup
- Configures the Application Gateway, linking it to the public IP and defining routing rules for incoming traffic.

#### 🔑 Key Vault Access
- Retrieves secrets (username and password) from Azure Key Vault for secure management of sensitive information.

#### 🖥️ Virtual Machine Scale Set Creation
- Deploys a scale set of Windows virtual machines for high availability and scalability, using secrets for credentials.

#### 🔄 Virtual Network Peering
- Establishes peering between the spoke network and a hub network for interconnectivity.

## Architecture Diagram
![spoke2](https://github.com/user-attachments/assets/d8dcfbd6-d7c6-4791-9c26-806b42a38493)

## Run the Terraform configurations :
Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan
```
```
terraform apply
```