<!-- BEGIN_TF_DOCS -->


```hcl
// resource group

resource "azurerm_resource_group" "sp_03rg" {                 
    name = var.resource_group_name
    location = var.resource_group_location
}

// virtual network

resource "azurerm_virtual_network" "sp_03vnet" {                
    for_each = var.vnet_details
    name = each.key
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.sp_03rg.name
    location = azurerm_resource_group.sp_03rg.location
    depends_on = [ azurerm_resource_group.sp_03rg ]
}

// Subnet

resource "azurerm_subnet" "subnet" {                        
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.sp_03vnet["sp03_vnet"].name
  resource_group_name = azurerm_resource_group.sp_03rg.name
  dynamic "delegation" {
    for_each = each.key == "sp03-subnet" ? [1] : []
    content{
        name = "appservice_delegation"
        service_delegation {
        name = "Microsoft.Web/serverFarms"
        actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
    }
    
  }
  depends_on = [ azurerm_resource_group.sp_03rg , azurerm_virtual_network.sp_03vnet ]
}

# Create an App Service Plan
resource "azurerm_app_service_plan" "app-service-plan" {
  name                = "App-service-plan"
  location            = azurerm_resource_group.sp_03rg.location
  resource_group_name = azurerm_resource_group.sp_03rg.name
  sku {
    tier = "Standard"
    size = "S1"
  }
  depends_on = [ azurerm_resource_group.sp_03rg, azurerm_virtual_network.sp_03vnet ]
}

# Create an App Service
resource "azurerm_app_service" "app-service" {
  name                = "sp03-app-service"
  location            = azurerm_resource_group.sp_03rg.location
  resource_group_name = azurerm_resource_group.sp_03rg.name
  app_service_plan_id = azurerm_app_service_plan.app-service-plan.id

  depends_on = [ azurerm_app_service_plan.app-service-plan ]
}

# integrate to hub
resource "azurerm_app_service_virtual_network_swift_connection" "vnet-integration" {
  app_service_id = azurerm_app_service.app-service.id
  subnet_id = azurerm_subnet.subnet["sp03-subnet"].id
  depends_on = [ azurerm_app_service.app-service , azurerm_subnet.subnet ]
}


 #  connect to hub

data "azurerm_virtual_network" "hub_vnet" {
  name ="hub_vnet"
  resource_group_name = "hub_rg"
}

# connect to peering spoke3 to hub
resource "azurerm_virtual_network_peering" "Sp03-To-hub" {
  name                      = "Sp03-To-hub"
  resource_group_name       = azurerm_resource_group.sp_03rg.name
  virtual_network_name      = azurerm_virtual_network.sp_03vnet["sp03_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.sp_03vnet , data.azurerm_virtual_network.hub_vnet  ]
}

#connect peering hub to spoke3
resource "azurerm_virtual_network_peering" "hub-To-Sp03" {
  name                      = "hub-To-Sp03"
  resource_group_name       = data.azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.sp_03vnet["sp03_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.sp_03vnet , data.azurerm_virtual_network.hub_vnet ]
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

- [azurerm_app_service.app-service](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service) (resource)
- [azurerm_app_service_plan.app-service-plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_plan) (resource)
- [azurerm_app_service_virtual_network_swift_connection.vnet-integration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection) (resource)
- [azurerm_resource_group.sp_03rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.sp_03vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Sp03-To-hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.hub-To-Sp03](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_resource_group_location"></a> [resource\_group\_location](#input\_resource\_group\_location)

Description: The Location of the Resource Group

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the Resource Group

Type: `string`

### <a name="input_subnet_details"></a> [subnet\_details](#input\_subnet\_details)

Description: The details of the Subnets

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

### <a name="input_vnet_details"></a> [vnet\_details](#input\_vnet\_details)

Description: The details of the VNET

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

### <a name="output_app-service"></a> [app-service](#output\_app-service)

Description: n/a

### <a name="output_app-service-plan"></a> [app-service-plan](#output\_app-service-plan)

Description: n/a

### <a name="output_sp_03rg"></a> [sp\_03rg](#output\_sp\_03rg)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->