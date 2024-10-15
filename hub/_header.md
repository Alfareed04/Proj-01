# Hub Resource Group
The Hub Resource Group offers a consolidated platform that delivers centralized services and networking across the entire infrastructure, serving as the main hub for connectivity and security oversight.

## Configuration Details

1. Create the Resource Group 🗂️
- Create a resource group to centralize all services and networking elements for the hub.

2. Create the Virtual Network 🌐
- Set up a virtual network for the hub, detailing the address range and configuration settings.

3. Create Subnets 🧩
- Divide the virtual network into distinct subnets, each assigned a unique address prefix and potential service delegations.

4. Allocate Public IP Addresses 🌍
- Assign public IP addresses to resources that require internet accessibility.

5. Implement a Bastion Host 🔐
- Deploy a Bastion Host to facilitate secure RDP/SSH access to virtual machines within the network, keeping them protected from public exposure.

6. Create a Virtual Network Gateway 🔗
- Create a VPN gateway to facilitate site-to-site VPN connections between on-premises infrastructure and Azure.

7. Create a Firewall 🛡️
- Establish a firewall to safeguard and regulate incoming and outgoing traffic across the network.

8. Create a Firewall Policy 📜
- Create a firewall policy to outline the rules and configurations for managing the Azure Firewall.

9. Organize IP Addresses into Groups 🏷️
- Group IP addresses for more straightforward management and application of firewall policies.

10. Configure Firewall Rules 🔧
- Set up network and application rules within the firewall policy to manage traffic flow effectively.

11. Enable Virtual Network Peering 🔄
- Create peering connections between the hub virtual network and spoke virtual networks to allow seamless communication.

### Integrate with On-Premises Network 🏢

1. Identify On-Premises Public IP and Virtual Network 🌍
- Determine the public IP address and define the virtual network for the on-premises environment.

2. Set Up a Local Network Gateway 🌐
- Create a local network gateway in Azure to represent the on-premises VPN device, including its public IP address and address space.

3. Establish a VPN Connection 🔗
- Connect the Azure virtual network gateway to the local network gateway on-premises, specifying the connection type (IPsec) and shared authentication key.

4. Create a Routing Table 🗺️
- Define a routing table to manage traffic flow between the on-premises network and Azure, adding necessary routes for directing traffic through the VPN gateway.

5. Associate the Routing Table with Subnets 🔗
- Connect the routing table to the relevant subnets in the hub virtual network to enforce the established routing rules.

## Architecture Diagram
![Hub](https://github.com/user-attachments/assets/b1f6209d-fec7-461e-8f4d-ed09559e1184)

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




