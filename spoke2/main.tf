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
    name = "project01keyvault"
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

 #  connect to hub(Spoke_2 <--> Hub)

data "azurerm_virtual_network" "hub_vnet" {
  name ="hub_vnet"
  resource_group_name = "hub_rg"
}

# Establish the Peering between Spoke_2 and Hub networks (Spoke_2 <--> Hub)
resource "azurerm_virtual_network_peering" "Sp02-To-hub" {
  name                      = "Sp02-To-hub"
  resource_group_name       = azurerm_resource_group.sp_02rg.name
  virtual_network_name      = azurerm_virtual_network.sp_02vnet["spoke_02_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.sp_02vnet, data.azurerm_virtual_network.hub_vnet  ]
}
# Establish the Peering between  Hub and Spoke-2 networks (Hub <--> Spoke_02)
resource "azurerm_virtual_network_peering" "hub-To-Sp02" {
  name                      = "hub-To-Sp02"
  resource_group_name       = data.azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.sp_02vnet["spoke_02_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.sp_02vnet , data.azurerm_virtual_network.hub_vnet ]
}
