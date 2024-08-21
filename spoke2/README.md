<!-- BEGIN_TF_DOCS -->


```hcl
// resource group

resource "azurerm_resource_group" "sp_02rg" {                 
    name = var.resource_group_name
    location = var.resource_group_location
}

// virtual network

resource "azurerm_virtual_network" "sp_02vnet" { 
    for_each = var.vnet_details               
    name = each.key
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.sp_02rg.name
    location = azurerm_resource_group.sp_02rg.location
    depends_on = [ azurerm_resource_group.sp_02rg ]
}

// Subnet

resource "azurerm_subnet" "subnet" {                        
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.sp_02vnet["spoke_02_vnet"].name
  resource_group_name = azurerm_resource_group.sp_02rg.name
  depends_on = [ azurerm_resource_group.sp_02rg , azurerm_virtual_network.sp_02vnet ]
}

// Network Security Group => Nsg

resource "azurerm_network_security_group" "nsg" {
  for_each = toset(local.subnet_names)
  name = "${each.key}-nsg"
  resource_group_name = azurerm_resource_group.sp_02rg.name
  location = azurerm_resource_group.sp_02rg.location

  dynamic "security_rule" {                          
     for_each = { for rule in local.rules_csv : rule.name => rule }
     content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  
  depends_on = [ azurerm_subnet.subnet ]
}


# // Nsg Association

# resource "azurerm_subnet_network_security_group_association" "nsgass" {
#   for_each = [for nsg in azurerm_network_security_group.nsg : nsg.id]
#   network_security_group_id = each.value
#   subnet_id = azurerm_subnet.subnet[each.key].id
#   depends_on = [ azurerm_subnet.subnet, azurerm_network_security_group.nsg ]
# }

# Create the Public IP for Application Gateway
resource "azurerm_public_ip" "public_ip" {
  name                = "Appgw-pip"
  location            = azurerm_resource_group.sp_02rg.location
  resource_group_name = azurerm_resource_group.sp_02rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
 
# Create the Application for their dedicated subnet

resource "azurerm_application_gateway" "appGW" {
  name                = "Appgw"
  resource_group_name = azurerm_resource_group.sp_02rg.name
  location = azurerm_resource_group.sp_02rg.location
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
 
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet["sp02-subnet1"].id
  }
 
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
 
  frontend_port {
    name = "frontend-port"
    port = 80
  }
 
  backend_address_pool {
    name = "appgw-backend-pool"
  }
 
  backend_http_settings {
    name                  = "appgw-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }
 
  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "frontend-port"
    protocol                       = "Http"
  }
 
  request_routing_rule {
    name                       = "appgw-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http-settings"
  }
    depends_on = [azurerm_resource_group.sp_02rg ,azurerm_subnet.subnet ,azurerm_public_ip.public_ip]
}
 
 data "azurerm_key_vault" "Key_vault" {
    name = "proj0001keyvault"
    resource_group_name = "spoke01_rg"
}
data "azurerm_key_vault_secret" "vm_admin_username" {
     name = "sp01username"
     key_vault_id = data.azurerm_key_vault.Key_vault.id
}
data "azurerm_key_vault_secret" "vm_admin_password" {
     name = "sp01password"
     key_vault_id = data.azurerm_key_vault.Key_vault.id
}

# Virtual Machine Scale Set

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "sp02-vmss"
  resource_group_name = azurerm_resource_group.sp_02rg.name
  location            = azurerm_resource_group.sp_02rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password      = data.azurerm_key_vault_secret.vm_admin_password.value

  network_interface {
    name = "sp02-vmss-nic"
    primary = true
    ip_configuration {
      name                          = "internal"
      subnet_id                     = azurerm_subnet.subnet["sp02-subnet2"].id
      application_gateway_backend_address_pool_ids = [local.application_gateway[0]]
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  
  depends_on = [ azurerm_resource_group.sp_02rg, azurerm_subnet.subnet, azurerm_application_gateway.appGW ]
}

#  #  connect to hub(Spoke_2 <--> Hub)

# data "azurerm_virtual_network" "hub_vnet" {
#   name ="hub_vnet"
#   resource_group_name = "hub_rg"
# }

# # Establish the Peering between Spoke_2 and Hub networks (Spoke_2 <--> Hub)
# resource "azurerm_virtual_network_peering" "Sp02-To-hub" {
#   name                      = "Sp02-To-hub"
#   resource_group_name       = azurerm_resource_group.sp_02rg.name
#   virtual_network_name      = azurerm_virtual_network.sp_02vnet["spoke_02_vnet"].name
#   remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = false
#   use_remote_gateways       = false
#   depends_on = [ azurerm_virtual_network.sp_02vnet, data.azurerm_virtual_network.hub_vnet  ]
# }
# # Establish the Peering between  Hub and Spoke-2 networks (Hub <--> Spoke_02)
# resource "azurerm_virtual_network_peering" "hub-To-Sp02" {
#   name                      = "hub-To-Sp02"
#   resource_group_name       = data.azurerm_virtual_network.hub_vnet.resource_group_name
#   virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
#   remote_virtual_network_id = azurerm_virtual_network.sp_02vnet["spoke_02_vnet"].id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = false
#   use_remote_gateways       = false
#   depends_on = [ azurerm_virtual_network.sp_02vnet , data.azurerm_virtual_network.hub_vnet ]
# }
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

- [azurerm_application_gateway.appGW](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) (resource)
- [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_public_ip.public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.sp_02rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.sp_02vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_windows_virtual_machine_scale_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) (resource)
- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) (data source)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password)

Description: The Password of the User

Type: `string`

### <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username)

Description: The Username of the User

Type: `string`

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

The following input variables are optional (have default values):

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: The name of CSV file containing NSG rules

Type: `string`

Default: `"rules.csv"`

## Outputs

The following outputs are exported:

### <a name="output_Sp02_rg"></a> [Sp02\_rg](#output\_Sp02\_rg)

Description: n/a

### <a name="output_Sp02_vnet"></a> [Sp02\_vnet](#output\_Sp02\_vnet)

Description: n/a

### <a name="output_appGW"></a> [appGW](#output\_appGW)

Description: n/a

### <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip)

Description: n/a

### <a name="output_subnet"></a> [subnet](#output\_subnet)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->