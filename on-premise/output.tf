output "on_prem_rg" {
  value = azurerm_resource_group.on_prem_rg
}

output "on_prem_vnet" {
  value = azurerm_virtual_network.on_prem_vnet
}

output "subnet" {
  value = azurerm_subnet.subnet
}

output "onprem-pip" {
 value = azurerm_public_ip.onprem-pip
}

output "onprem-vpngw" {
 value = azurerm_virtual_network_gateway.onprem-vpngw
}