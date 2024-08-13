
output "Sp02_rg" {
  value = azurerm_resource_group.sp_02rg
}

output "Sp02_vnet" {
  value = azurerm_virtual_network.sp_02vnet
}

output "subnet" {
  value = azurerm_subnet.subnet
}

output "public_ip" {
  value = azurerm_public_ip.public_ip
}

output "appGW" {
  value = azurerm_application_gateway.appGW
}
