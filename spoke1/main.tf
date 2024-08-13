data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

// resource group

resource "azurerm_resource_group" "sp_01rg" {                 
    name = var.resource_group_name
    location = var.location
}

// virtual network

resource "azurerm_virtual_network" "sp_01vnet" {                
  for_each = var.vnet_details
  name                = each.key
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.sp_01rg.location
  resource_group_name = azurerm_resource_group.sp_01rg.name
  depends_on          = [azurerm_resource_group.sp_01rg]
}

// Subnet

resource "azurerm_subnet" "subnet" {                        
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.sp_01vnet["spoke_01_vnet"].name
  resource_group_name = azurerm_resource_group.sp_01rg.name
  depends_on = [ azurerm_resource_group.sp_01rg , azurerm_virtual_network.sp_01vnet ]
}

// Network Security Group => Nsg

resource "azurerm_network_security_group" "nsg" {
  for_each = local.subnet_names
  name = "${each.key}-nsg"
  resource_group_name = azurerm_resource_group.sp_01rg.name
  location = azurerm_resource_group.sp_01rg.location

  dynamic "security_rule" {                           
     for_each = { for rule in local.rules_csv : rule.name => rule }
     content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  
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

// Keyvault

resource "azurerm_key_vault" "Key_vault" {
  name                        = var.Key_vault
  resource_group_name = azurerm_resource_group.sp_01rg.name
  location = azurerm_resource_group.sp_01rg.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = true
  soft_delete_retention_days = 30
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azuread_client_config.current.object_id

    secret_permissions = [
      "Get",
      "Set",
      "Backup",
      "Delete",
      "Purge", 
      "List",
      "Recover",
      "Restore",
    ]
  }
  depends_on = [ azurerm_resource_group.sp_01rg ]
}

// Key vault Username

resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "spoke01username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

// Key vault Password

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "spoke01password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

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

depends_on = [ azurerm_resource_group.sp_01rg, azurerm_subnet.subnet, azurerm_network_interface.nic ]
}

// storage account

resource "azurerm_storage_account" "stg-act" {
  name                     = "azurestorage09871"
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

# # Mount the fileshare to Vitrual Machine
# resource "azurerm_virtual_machine_extension" "fileshare-mount" {
#   name                 = "vm-mount"
#   virtual_machine_id   = azurerm_windows_virtual_machine.vm["sp01-subnet1"].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.9"

#   protected_settings = <<SETTINGS
#   {
#    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.base64EncodedScript }')) | Out-File -filepath postBuild.ps1\" && powershell -ExecutionPolicy Unrestricted -File postBuild.ps1"
#   }
#   SETTINGS

#   depends_on = [azurerm_windows_virtual_machine.vm]
# }

 #  connect to hub(Sp01 <--> Hub)

data "azurerm_virtual_network" "hub_vnet" {
  name ="hub_vnet"
  resource_group_name = "hub_rg"
}

# Establish the Peering between Spoke_1 and Hub networks (Sp01 <--> Hub)
resource "azurerm_virtual_network_peering" "Sp01-To-hub" {
  name                      = "Sp01-To-hub"
  resource_group_name       = azurerm_resource_group.sp_01rg.name
  virtual_network_name      = azurerm_virtual_network.sp_01vnet["spoke_01_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.sp_01vnet , data.azurerm_virtual_network.hub_vnet  ]
}
# Establish the Peering between  Hub and Sp01 networks (Hub <--> Sp01)
resource "azurerm_virtual_network_peering" "hub-To-Sp01" {
  name                      = "hub-To-Sp01"
  resource_group_name       = data.azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.sp_01vnet["spoke_01_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.sp_01vnet , data.azurerm_virtual_network.hub_vnet ]
}

