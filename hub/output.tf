output "hub_rg" {
  value = azurerm_resource_group.hub_rg
}

output "hub_vnet" {
  value = azurerm_virtual_network.hub_vnet
}

output "subnet" {
  value = azurerm_subnet.subnet
}
 output "public_ip" {
  value = azurerm_public_ip.public_ip
 }
  output "vpn_gateway" {
  value = azurerm_virtual_network_gateway.vpn_gateway
 }
 output "firewall" {
    value = azurerm_firewall.firewall
 }