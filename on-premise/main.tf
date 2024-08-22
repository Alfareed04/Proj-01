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

# Fetch the data from Hub Gateway Public_IP (IP_address)
data "azurerm_public_ip" "public_ip" {
  name = "GatewaySubnet-IP"
  resource_group_name = "hub_rg"
}

# Fetch the data from Hub Virtual Network (address_space)
data "azurerm_virtual_network" "hub_vnet" {
  name = "hub_vnet"
  resource_group_name = "hub_rg"
}

# Created on Local Network Gateway

resource "azurerm_local_network_gateway" "onprem_lngw" {
  name                = "onprem-local-network-gateway"
  resource_group_name = azurerm_resource_group.on_prem_rg.name
  location            = azurerm_resource_group.on_prem_rg.location
  gateway_address = data.azurerm_public_ip.public_ip.ip_address
  address_space   = [data.azurerm_virtual_network.hub_vnet.address_space[0]]
  depends_on = [ azurerm_public_ip.onprem-pip, azurerm_virtual_network_gateway.onprem-vpngw,
   data.azurerm_public_ip.public_ip, data.azurerm_virtual_network.hub_vnet ]
}

# Created On Connection

resource "azurerm_virtual_network_gateway_connection" "onprem_connection" {
  name                           = "onprem-vpn-connection"
  location                       = azurerm_resource_group.on_prem_rg.location
  resource_group_name            = azurerm_resource_group.on_prem_rg.name
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.onprem-vpngw.id
  local_network_gateway_id       = azurerm_local_network_gateway.onprem_lngw.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                      = "your-shared-key"

  depends_on = [ azurerm_virtual_network_gateway.onprem-vpngw, azurerm_local_network_gateway.onprem_lngw ]
}

data "azurerm_key_vault" "Key_vault" {
    name = "project01keyvault"
    resource_group_name = "spoke01_rg"
}
data "azurerm_key_vault_secret" "vm_admin_username" {
     name = "spoke01username"
     key_vault_id = data.azurerm_key_vault.Key_vault.id
}
data "azurerm_key_vault_secret" "vm_admin_password" {
     name = "spoke01password"
     key_vault_id = data.azurerm_key_vault.Key_vault.id
}

# Created on nic

resource "azurerm_network_interface" "onprem_nic" {
  name                = "onprem-subnet-nic"
  location            = azurerm_resource_group.on_prem_rg.location
  resource_group_name = azurerm_resource_group.on_prem_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet["onprem-subnet"].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_resource_group.on_prem_rg, azurerm_subnet.subnet ]
}

//created to virtual machine

resource "azurerm_windows_virtual_machine" "onprem_vm" {
  name                  = "onprem-vm"
  location              = azurerm_resource_group.on_prem_rg.location
  resource_group_name   = azurerm_resource_group.on_prem_rg.name
  network_interface_ids = [azurerm_network_interface.onprem_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name              = "onprem-os-disk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  computer_name  = "onpremvm"
  admin_username = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password = data.azurerm_key_vault_secret.vm_admin_password.value
}

#create a route table
resource "azurerm_route_table" "route_table" {
  name = "onpremise-To-spoke01"
  location = azurerm_resource_group.on_prem_rg.location
  resource_group_name = azurerm_resource_group.on_prem_rg.name

  route {
    name = "ToSpoke01"
    address_prefix = "10.30.0.0/16"   //spoke_1 ip
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.0.4"
    
  }
  depends_on = [ azurerm_resource_group.on_prem_rg ]
}

#Associate the route table with  subnet
resource "azurerm_subnet_route_table_association" "route-table-association" {
   subnet_id                 = azurerm_subnet.subnet["onprem-subnet"].id
   route_table_id = azurerm_route_table.route_table.id
   depends_on = [ azurerm_subnet.subnet , azurerm_route_table.route_table ]
}