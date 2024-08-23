# On-premises Resource Group
This resource group contains virtual networks (VNets) with associated subnets, network security groups (NSGs), a virtual network gateway, a VPN connection, and virtual network integration. The setup is flexible, enabling scalable and tailored deployments.

# On-Premises Network Connectivity

1. Begin by setting up a Resource Group designated for On-Premises.
2. Proceed to create a Hub Virtual Network, ensuring it has a defined address space.
3. The Hub Virtual Network should include several subnets, each with specified address prefixes.
4. Set up a subnet specifically for the VPN Gateway.
5. Finally, establish the Local Network Gateway and Connection service to link the On-Premises setup with the Hub.

## Architecture Diagram


###### Run the Terraform configurations :
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