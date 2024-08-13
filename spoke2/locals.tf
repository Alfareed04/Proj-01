locals {
  rules_csv = csvdecode(file(var.rules_file))
  subnet_names = [ for i in azurerm_subnet.subnet : i.name]
  nsg_names = [for nsg in azurerm_network_security_group.nsg : nsg.name]
  subnet_id = {for s in azurerm_subnet.subnet : s.name => s.id}
  application_gateway = [for appgw in azurerm_application_gateway.appGW.backend_address_pool : appgw.id]
}