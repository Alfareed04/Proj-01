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


 #  connect to hub(Sp03 <--> Hub)

data "azurerm_virtual_network" "hub_vnet" {
  name ="hub_vnet"
  resource_group_name = "hub_rg"
}

# connect to peering spoke3 to hub (Sp03 <--> hub)
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

#connect peering hub to spoke3(hub <--> Sp03)
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