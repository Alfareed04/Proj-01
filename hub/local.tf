locals {
  subnet_name = [for sub in azurerm_subnet.subnet : sub.name]
}