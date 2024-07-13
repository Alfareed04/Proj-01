locals {
  subnet_names =[for i in azurerm_subnet.subnet : i.name]
  nsg_names = {for idx, nsg in azurerm_network_security_group.nsg : idx => nsg.name}
  subnet_id = [for i in azurerm_subnet.subnet : i.id]
  subnet_name = toset(["sp_01_subnet1", "sp_01_subnet2"])
}