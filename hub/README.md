<!-- BEGIN_TF_DOCS -->


```hcl
// resource group

resource "azurerm_resource_group" "hub_rg" {                 
    name = var.resource_group_name
    location = var.resource_group_location
}

// virtual network

resource "azurerm_virtual_network" "hub_vnet" {    
  for_each = var.vnet_details             
    name = each.key
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.hub_rg.name
    location = azurerm_resource_group.hub_rg.location
    depends_on = [ azurerm_resource_group.hub_rg ]
}

// Subnet

resource "azurerm_subnet" "subnet" {                        
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.hub_vnet["hub_vnet"].name
  resource_group_name = azurerm_resource_group.hub_rg.name
  depends_on = [ azurerm_resource_group.hub_rg , azurerm_virtual_network.hub_vnet ]
}

# Create the Public IP's for Azure Firewall , VPN Gateway and Azure Bastion Host 
resource "azurerm_public_ip" "public_ip" {
  for_each = toset(local.subnet_name)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.hub_rg ]
}

# Create the Azure Bastion
resource "azurerm_bastion_host" "hub_bastion" {
  name                = "bastion"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku = "Standard"
  ip_configuration {
    name = "ipconfig"
    public_ip_address_id = azurerm_public_ip.public_ip["AzureBastionSubnet"].id
    subnet_id = azurerm_subnet.subnet["AzureBastionSubnet"].id 
  }
  depends_on = [ azurerm_subnet.subnet , azurerm_public_ip.public_ip]
}
 
# Create the Azure Firewall policy
resource "azurerm_firewall_policy" "firewall_policy" {
  name                = "hub-firewall-policy"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku = "Standard"
  depends_on = [ azurerm_resource_group.hub_rg , azurerm_subnet.subnet ]
}
 
# Create the Azure Firewall
resource "azurerm_firewall" "firewall" {
  name                = "Hub-Firewall"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
   sku_name = "AZFW_VNet"
   sku_tier = "Standard"

  ip_configuration {
    name                 = "firewallconfiguration"
    subnet_id            = azurerm_subnet.subnet["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.public_ip["AzureFirewallSubnet"].id
  }
  firewall_policy_id = azurerm_firewall_policy.firewall_policy.id

  depends_on = [ azurerm_resource_group.hub_rg , azurerm_public_ip.public_ip , 
  azurerm_subnet.subnet , azurerm_firewall_policy.firewall_policy ]
}

# Create the Group Ip addresses
resource "azurerm_ip_group" "ip_grp" {
  name                = "ip-Group"
  resource_group_name = azurerm_resource_group.hub_rg.name
  location            = azurerm_resource_group.hub_rg.location
  cidrs = [ "10.30.0.0/16" , "10.40.0.0/16" , "10.50.0.0/16" ]
  depends_on = [ azurerm_resource_group.hub_rg ]
}

# Firewall rule
resource "azurerm_firewall_policy_rule_collection_group" "firewall_rule" {
  name                = "firewall-rule"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy.id
  priority            = 100

  nat_rule_collection {           
    name     = "dnat-rule-collection"
    priority = 100
    action   = "Dnat"

    rule {
      name             = "Allow-RDP"
      source_addresses = ["103.25.44.14"]   # My Router IP
      destination_ports = ["3389"]
      destination_address = azurerm_public_ip.public_ip["AzureFirewallSubnet"].ip_address
      translated_address = "10.100.2.4"   # destination VM IP
      translated_port    = "3389"
      protocols         = ["TCP"]
    }
  }
 
  network_rule_collection {     
    name     = "network-rule-collection"
    priority = 200
    action   = "Allow"

    rule {
      name = "allow-spokes"
      source_addresses = [ "10.10.0.0/16" ]     
      destination_addresses = [ "10.30.0.0/16" ] 
      destination_ports = [ "*" ]
      protocols = [ "Any" ]
    }
  }
 
  # application_rule_collection {       
  #   name     = "application-rule-collection"
  #   priority = 300
  #   action   = "Allow"
 
  #   rule {
  #     name             = "allow-web"
  #     description      = "Allow-Web-Access"
  #     source_addresses = ["10.20.1.4"]  # Allow website only from [10.20.1.4]
  #     protocols {
  #       type = "Http"
  #       port = 80
  #     }
  #     protocols {
  #       type = "Https"
  #       port = 443
  #     } 
  #     destination_fqdns = ["*.microsoft.com"]  
  #   }
  # } 
  depends_on = [ azurerm_firewall.firewall , azurerm_ip_group.ip_grp ]
}

# Create the VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "hub-vpn-gateway"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.public_ip["GatewaySubnet"].id
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnet["GatewaySubnet"].id
  }
  depends_on = [ azurerm_resource_group.hub_rg , azurerm_public_ip.public_ip , azurerm_subnet.subnet ]
}

# Fetch the data from On_premises Gateway Public_IP (IP_address)
data "azurerm_public_ip" "onprem-pip" {
  name = "onprem-public-ip"
  resource_group_name = "onpremise_rg"
}

# Fetch the data from On_Premise Virtual Network (address_space)
data "azurerm_virtual_network" "on_prem_vnet" {
  name = "onprem_vnet"
  resource_group_name = "onpremise_rg"
}

# Create the Local Network Gateway for VPN Gateway
resource "azurerm_local_network_gateway" "hub_lgw" {
  name                = "Hub-To-OnPremise"
  resource_group_name = azurerm_virtual_network_gateway.vpn_gateway.resource_group_name
  location = azurerm_virtual_network_gateway.vpn_gateway.location
  gateway_address     = data.azurerm_public_ip.onprem-pip.ip_address        
  address_space       = [data.azurerm_virtual_network.on_prem_vnet.address_space[0]]  
  depends_on = [ azurerm_public_ip.public_ip , azurerm_virtual_network_gateway.vpn_gateway , 
              data.azurerm_public_ip.onprem-pip ,data.azurerm_virtual_network.on_prem_vnet ]
}

 # Create the VPN-Connection for onprem
resource "azurerm_virtual_network_gateway_connection" "connection" { 
  name                           = "hub-to-onPrem-vpn-connection"
  resource_group_name = azurerm_virtual_network_gateway.vpn_gateway.resource_group_name
  location = azurerm_virtual_network_gateway.vpn_gateway.location
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.vpn_gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.hub_lgw.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "YourSharedKey" 

  depends_on = [ azurerm_virtual_network_gateway.vpn_gateway , azurerm_local_network_gateway.hub_lgw]
}

# Creates the route table
resource "azurerm_route_table" "route_table" {
  name                = "Hub-To-Gateway"
  resource_group_name = azurerm_resource_group.hub_rg.name
  location = azurerm_resource_group.hub_rg.location
  depends_on = [ azurerm_resource_group.hub_rg , azurerm_subnet.subnet ]
}

# Creates route
resource "azurerm_route" "route_2" {
  name                   = "ToSpk01"
  resource_group_name = azurerm_route_table.route_table.resource_group_name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix = "10.30.0.0/16"     # destnation network address space
  next_hop_type          = "VirtualAppliance" 
  next_hop_in_ip_address = "10.20.1.4"   # Firewall private IP
  depends_on = [ azurerm_route_table.route_table ]
}

# Associate the route table
resource "azurerm_subnet_route_table_association" "route-table-ass" {
   subnet_id                 = azurerm_subnet.subnet["GatewaySubnet"].id
   route_table_id = azurerm_route_table.route_table.id
  depends_on = [ azurerm_subnet.subnet , azurerm_route_table.route_table ]
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_bastion_host.hub_bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) (resource)
- [azurerm_firewall.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall) (resource)
- [azurerm_firewall_policy.firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy) (resource)
- [azurerm_firewall_policy_rule_collection_group.firewall_rule](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) (resource)
- [azurerm_ip_group.ip_grp](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ip_group) (resource)
- [azurerm_local_network_gateway.hub_lgw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) (resource)
- [azurerm_public_ip.public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route.route_2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [azurerm_route_table.route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.route-table-ass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_gateway.vpn_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) (resource)
- [azurerm_virtual_network_gateway_connection.connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) (resource)
- [azurerm_public_ip.onprem-pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) (data source)
- [azurerm_virtual_network.on_prem_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_resource_group_location"></a> [resource\_group\_location](#input\_resource\_group\_location)

Description: The Location of the resource group

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the resource group

Type: `string`

### <a name="input_subnet_details"></a> [subnet\_details](#input\_subnet\_details)

Description: Map of subnet configurations

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

### <a name="input_vnet_details"></a> [vnet\_details](#input\_vnet\_details)

Description: Map of virtual network details

Type:

```hcl
map(object({
    vnet_name = string
    address_space = string
  }))
```

## Optional Inputs

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_firewall"></a> [firewall](#output\_firewall)

Description: n/a

### <a name="output_hub_rg"></a> [hub\_rg](#output\_hub\_rg)

Description: n/a

### <a name="output_hub_vnet"></a> [hub\_vnet](#output\_hub\_vnet)

Description: n/a

### <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip)

Description: n/a

### <a name="output_subnet"></a> [subnet](#output\_subnet)

Description: n/a

### <a name="output_vpn_gateway"></a> [vpn\_gateway](#output\_vpn\_gateway)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->