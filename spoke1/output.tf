output "sp_01rg" {
    value = azurerm_resource_group.sp_01rg 
}

output "sp_01vnet" {
  value = azurerm_virtual_network.sp_01vnet
}

output "subnet" {
  value = azurerm_subnet.subnet
}

 output "vm" {
   value = azurerm_windows_virtual_machine.vm
   sensitive = true
 }



output "Key_Vault" {
  value = azurerm_key_vault.Key_vault
}



 output "fileshare" {
   value = azurerm_storage_share.fileshare
 }