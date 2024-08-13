locals {
  rules_csv = csvdecode(file(var.rules_file))
  subnet_names ={for i, sub in azurerm_subnet.subnet: i => sub.name}
  nsg_names = [for nsg in azurerm_network_security_group.nsg : nsg.name]
  subnet_id = [for i in azurerm_subnet.subnet : i.id]

  # yourPowerShellScript= try(file("scripts/mount-fileshare.ps1"), null)
  # base64EncodedScript = base64encode(local.yourPowerShellScript)

}