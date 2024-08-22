locals {
  rules_csv = csvdecode(file(var.rules_file))
  subnet_names = [ for i in azurerm_subnet.subnet : i.name]
  application_gateway = [for appgw in azurerm_application_gateway.appGW.backend_address_pool : appgw.id]
}