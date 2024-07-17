data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

// resource group

resource "azurerm_resource_group" "sp_01rg" {                 
    name = var.resource_group_name
    location = var.resource_group_location
}

// virtual network

resource "azurerm_virtual_network" "sp_01vnet" {                
    name = var.virtual_network_name
    address_space = [var.virtual_network_address_space]
    resource_group_name = azurerm_resource_group.sp_01rg.name
    location = azurerm_resource_group.sp_01rg.location
    depends_on = [ azurerm_resource_group.sp_01rg ]
}

// Subnet

resource "azurerm_subnet" "subnet" {                        
  for_each = var.subnet_details
  name = each.value.name
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.sp_01vnet.name
  resource_group_name = azurerm_resource_group.sp_01rg.name
  depends_on = [ azurerm_resource_group.sp_01rg , azurerm_virtual_network.sp_01vnet ]
}

// Network Security Group => Nsg

resource "azurerm_network_security_group" "nsg" {
  for_each = local.subnet_names
  name = "${each.key}-nsg"
  resource_group_name = azurerm_resource_group.sp_01rg.name
  location = azurerm_resource_group.sp_01rg.location
  depends_on = [ azurerm_subnet.subnet ]
}

resource "azurerm_subnet_network_security_group_association" "nsgass" {
  for_each = {for id, nsg in azurerm_network_security_group.nsg : id => nsg.id}
  network_security_group_id = each.value
  subnet_id = azurerm_subnet.subnet[each.key].id
  depends_on = [ azurerm_subnet.subnet, azurerm_network_security_group.nsg ]
}

// Nic

resource "azurerm_network_interface" "nic" {
  for_each = local.subnet_names
  name = "${each.key}-nic"
  resource_group_name = azurerm_resource_group.sp_01rg.name
  location = azurerm_resource_group.sp_01rg.location

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.subnet[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_subnet.subnet ]
}

# // Keyvault

# resource "azurerm_key_vault" "Key_vault" {
#   name                        = "MyKeyVault04faa"
#   resource_group_name = azurerm_resource_group.sp_01rg.name
#   location = azurerm_resource_group.sp_01rg.location
#   sku_name                    = "standard"
#   tenant_id                   = data.azurerm_client_config.current.tenant_id
#   purge_protection_enabled    = true
#   soft_delete_retention_days = 30
#   access_policy {
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     object_id = data.azuread_client_config.current.object_id
 
#     secret_permissions = [
#       "Get",
#       "Set",
#     ]
#   }
#   depends_on = [ azurerm_resource_group.sp_01rg ]
# }

# // Key vault Username

# resource "azurerm_key_vault_secret" "vm_admin_username" {
#   name         = "spokekeyvaultfar0412"
#   value        = var.admin_username
#   key_vault_id = azurerm_key_vault.Key_vault.id
#   depends_on = [ azurerm_key_vault.Key_vault ]
# }

# // Key vault Password

# resource "azurerm_key_vault_secret" "vm_admin_password" {
#   name         = "spokekeyvaultfarpassword"
#   value        = var.admin_password
#   key_vault_id = azurerm_key_vault.Key_vault.id
#   depends_on = [ azurerm_key_vault.Key_vault ]
# }

// virtual machine

resource "azurerm_windows_virtual_machine" "vm" {
#   count               = var.vm_count
for_each = {for i, nic in azurerm_network_interface.nic : i => nic.id}
  name                = "${each.key}-vm" //sp_01_subnet1-vm
  location            = azurerm_resource_group.sp_01rg.location
  resource_group_name = azurerm_resource_group.sp_01rg.name
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  

  network_interface_ids = [each.value]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

#   zone = var.availability_zones

depends_on = [ azurerm_resource_group.sp_01rg, azurerm_subnet.subnet, azurerm_network_interface.nic ]
}

// storage account

resource "azurerm_storage_account" "stg-act" {
  name                     = "azurestorage0341"
  resource_group_name      = azurerm_resource_group.sp_01rg.name
  location                 = azurerm_resource_group.sp_01rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [ azurerm_resource_group.sp_01rg ]
}

resource "azurerm_storage_share" "fileshare" {
  name                 = "fileshare"
  storage_account_name = azurerm_storage_account.stg-act.name
  quota                = 10

  depends_on = [ azurerm_resource_group.sp_01rg, azurerm_storage_account.stg-act ]
}

// mount 

resource "azurerm_virtual_machine_extension" "vm-mount" {
  name                 = "spoke1-vm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm["sp01-subnet1"].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.compute/vm-custom-script-windows/scripts/customscript.ps1"],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File customscript.ps1"
    }
  SETTINGS
}