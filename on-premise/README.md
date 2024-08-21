<!-- BEGIN_TF_DOCS -->


```hcl
// resource group

resource "azurerm_resource_group" "on_prem_rg" {                 
    name = var.resource_group_name
    location = var.location
}

// virtual network

resource "azurerm_virtual_network" "on_prem_vnet" {                
    for_each = var.vnet_details
    name = each.key
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.on_prem_rg.name
    location = azurerm_resource_group.on_prem_rg.location
    depends_on = [ azurerm_resource_group.on_prem_rg ]
}

// Subnet

resource "azurerm_subnet" "subnet" {                        
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.on_prem_vnet["onprem_vnet"].name
  resource_group_name = azurerm_resource_group.on_prem_rg.name
  depends_on = [ azurerm_resource_group.on_prem_rg , azurerm_virtual_network.on_prem_vnet ]
}

# Created on public ip

resource "azurerm_public_ip" "onprem-pip" {
  name                = "onprem-public-ip"
  location            = azurerm_resource_group.on_prem_rg.location
  resource_group_name = azurerm_resource_group.on_prem_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
 
# Created on Virtual network gateway

resource "azurerm_virtual_network_gateway" "onprem-vpngw" {
  name                = "onprem-vpn-gateway"
  location            = azurerm_resource_group.on_prem_rg.location
  resource_group_name = azurerm_resource_group.on_prem_rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet["GatewaySubnet"].id
  }

  depends_on = [ azurerm_resource_group.on_prem_rg, azurerm_virtual_network.on_prem_vnet, azurerm_subnet.subnet ]
}

# # Fetch the data from Hub Gateway Public_IP (IP_address)
# data "azurerm_public_ip" "public_ip" {
#   name = "GatewaySubnet-IP"
#   resource_group_name = "hub_rg"
# }

# # Fetch the data from Hub Virtual Network (address_space)
# data "azurerm_virtual_network" "hub_vnet" {
#   name = "hub_vnet"
#   resource_group_name = "hub_rg"
# }

# # Created on Local Network Gateway

# resource "azurerm_local_network_gateway" "onprem_lngw" {
#   name                = "onprem-local-network-gateway"
#   resource_group_name = azurerm_resource_group.on_prem_rg.name
#   location            = azurerm_resource_group.on_prem_rg.location

#   gateway_address = data.azurerm_public_ip.public_ip.ip_address
#   address_space   = [data.azurerm_virtual_network.hub_vnet.address_space[0]]

#   depends_on = [ azurerm_public_ip.onprem-pip, azurerm_virtual_network_gateway.onprem-vpngw,
#    data.azurerm_public_ip.public_ip, data.azurerm_virtual_network.hub_vnet ]
# }

# # Created On Connection

# resource "azurerm_virtual_network_gateway_connection" "onprem_connection" {
#   name                           = "onprem-vpn-connection"
#   location                       = azurerm_resource_group.on_prem_rg.location
#   resource_group_name            = azurerm_resource_group.on_prem_rg.name
#   virtual_network_gateway_id     = azurerm_virtual_network_gateway.onprem-vpngw.id
#   local_network_gateway_id       = azurerm_local_network_gateway.onprem_lngw.id
#   type                           = "IPsec"
#   connection_protocol            = "IKEv2"
#   shared_key                      = "your-shared-key"

#   depends_on = [ azurerm_virtual_network_gateway.onprem-vpngw, azurerm_local_network_gateway.onprem_lngw ]
# }

# data "azurerm_key_vault" "Key_vault" {
#     name = "proj0001keyvault"
#     resource_group_name = "spoke01_rg"
# }
# data "azurerm_key_vault_secret" "vm_admin_username" {
#      name = "sp01username"
#      key_vault_id = data.azurerm_key_vault.Key_vault.id
# }
# data "azurerm_key_vault_secret" "vm_admin_password" {
#      name = "sp01password"
#      key_vault_id = data.azurerm_key_vault.Key_vault.id
# }

# # Created on nic

# resource "azurerm_network_interface" "onprem_nic" {
#   name                = "onprem-subnet-nic"
#   location            = azurerm_resource_group.on_prem_rg.location
#   resource_group_name = azurerm_resource_group.on_prem_rg.name

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.subnet["onprem-subnet"].id
#     private_ip_address_allocation = "Dynamic"
#   }
#   depends_on = [ azurerm_resource_group.on_prem_rg, azurerm_subnet.subnet ]
# }

# //created to virtual machine

# resource "azurerm_windows_virtual_machine" "onprem_vm" {
#   name                  = "onprem-vm"
#   location              = azurerm_resource_group.on_prem_rg.location
#   resource_group_name   = azurerm_resource_group.on_prem_rg.name
#   network_interface_ids = [azurerm_network_interface.onprem_nic.id]
#   size                  = "Standard_DS1_v2"

#   os_disk {
#     name              = "onprem-os-disk"
#     caching           = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }

#   computer_name  = "onpremvm"
#   admin_username = data.azurerm_key_vault_secret.vm_admin_username.value
#   admin_password = data.azurerm_key_vault_secret.vm_admin_password.value
# }

# Creates the route table
resource "azurerm_route_table" "route_table" {
  name                = "Onprem-To-Spoke"
  resource_group_name = azurerm_resource_group.on_prem_rg.name
  location = azurerm_resource_group.on_prem_rg.location
  depends_on = [ azurerm_resource_group.on_prem_rg , azurerm_subnet.subnet ]
}

# Creates the route in the route table (OnPrem-Firewall-Spoke)
resource "azurerm_route" "route_01" {
  name                   = "ToSpoke01"
  resource_group_name = azurerm_resource_group.on_prem_rg.name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix = "10.30.0.0/16"     # destnation network address space
  next_hop_type      = "VirtualNetworkGateway" 
  depends_on = [ azurerm_route_table.route_table ]
}

# Associate the route table with their subnet
resource "azurerm_subnet_route_table_association" "route-table-association" {
   subnet_id                 = azurerm_subnet.subnet["onprem-subnet"].id
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

- [azurerm_public_ip.onprem-pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.on_prem_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route.route_01](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [azurerm_route_table.route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.route-table-association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.on_prem_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_gateway.onprem-vpngw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password)

Description: The Password of the User

Type: `string`

### <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username)

Description: The Username of the User

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

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

The following input variables are optional (have default values):

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: The name of CSV file containing NSG rules

Type: `string`

Default: `"rules.csv"`

## Outputs

The following outputs are exported:

### <a name="output_on_prem_rg"></a> [on\_prem\_rg](#output\_on\_prem\_rg)

Description: n/a

### <a name="output_on_prem_vnet"></a> [on\_prem\_vnet](#output\_on\_prem\_vnet)

Description: n/a

### <a name="output_onprem-pip"></a> [onprem-pip](#output\_onprem-pip)

Description: n/a

### <a name="output_onprem-vpngw"></a> [onprem-vpngw](#output\_onprem-vpngw)

Description: n/a

### <a name="output_subnet"></a> [subnet](#output\_subnet)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->