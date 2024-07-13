data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

resource "azurerm_resource_group" "rg" {                 // Resource Group
    name = var.resource_group_name
    location = var.resource_group_location
}

resource "azurerm_virtual_network" "vnet" {                // Virtual Network
    name = var.virtual_network_name
    address_space = [var.virtual_network_address_space]
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    depends_on = [ azurerm_resource_group.rg ]
}

resource "azurerm_subnet" "subnet" {                        // Subnet
  for_each = var.subnet_details
  name = each.value.name
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [ azurerm_resource_group.rg , azurerm_virtual_network.vnet ]
}

resource "azurerm_network_security_group" "nsg" {
  for_each = toset([for i in azurerm_subnet.subnet : i.name])
  name = "${each.key}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  depends_on = [ azurerm_subnet.subnet ]
}

resource "azurerm_subnet_network_security_group_association" "nsgass" {
  for_each = {for id, nsg in azurerm_network_security_group.nsg : id => nsg.id}
  network_security_group_id = each.value
  subnet_id = azurerm_subnet.subnet[each.key].id
  depends_on = [ azurerm_subnet.subnet, azurerm_network_security_group.nsg ]
}

resource "azurerm_network_interface" "nic" {
  for_each = local.subnet_name
  name = "${each.key}-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.subnet[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_subnet.subnet ]
}

// Keyvault

resource "azurerm_key_vault" "Key_vault" {
  name                        = "MyKeyVaultfareed"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
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
    ]
  }
  depends_on = [ azurerm_resource_group.rg ]
}

# resource "azurerm_linux_virtual_machine" "vm" {
#   count               = var.vm_count
#   name                = "${each.key}_vm"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   size                = "Standard_B1s"
#   admin_username      = "adminuser"
#   admin_password = 

#   network_interface_ids = [
#     azurerm_network_interface.example[count.index].id,
#   ]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   zone = var.availability_zones[count.index]
# }
