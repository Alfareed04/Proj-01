## Spoke01 Resource Group
The Spoke01 Resource Group establishes a virtual network with subnets, NSGs, VMs, and storage in a secure Azure environment. It enables isolated, scalable infrastructure for workload management within the larger cloud network.

## 🚀 Cloud Infrastructure Setup in Azure

1. 🔍 Client Configuration:
- Retrieve Azure and Azure AD client configuration details using azurerm_client_config and azuread_client_config data blocks.

2. 🏗️ Resource Group:
- Create the Spoke01 resource group (sp_01rg), the container for all resources in the spoke network.

3. 🌐 Virtual Network (VNet):
- Define a vNet (sp_01vnet) usi- ng variable-based details.
- Assign a specific address space and tie the vNet to the resource group location.

4. 📌 Subnets:
- Create subnets within the vNet, using spoke_01_vnet as the virtual network reference.
- Assign each subnet a unique address prefix.

5. 🔒 Network Security Group (NSG):
- Define NSGs to manage traffic for each subnet.
- Use dynamic security rules from a local CSV file to control inbound and outbound traffic.

6. 🔗 NSG Association:
- Associate NSGs with subnets to enforce security policies.

7. 💻 Network Interface (NIC):
- Create NICs for each subnet, enabling virtual machines to connect to the network.

8. 🔑 Key Vault:
- Set up an Azure Key Vault for secure secret management (e.g., VM admin credentials).
- Set access policies for secret management permissions.

9. 🛡️ Key Vault Secrets:
- Store the VM admin username and password as secrets in the Key Vault.

10. 💻 Virtual Machines (VM):
- Deploy Windows VMs with the created NICs.
- Use the Key Vault to retrieve admin credentials and deploy a standard OS image.

11. 📦 Storage Account & File Share:
- Set up a Storage Account and File Share for storing and sharing data across the environment.

12. 🖇️ Mount File Share to VM:
- Configure a VM extension to mount the File Share to the Windows VM via PowerShell.

## Architecture Diagram
![spoke1](https://github.com/user-attachments/assets/4f2f4d93-8e6e-4430-a312-b3058dfa88da)


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