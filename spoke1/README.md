<!-- BEGIN_TF_DOCS -->


```hcl
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
  name         = "sp01username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

// Key vault Password

resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "sp01password"
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
  name                     = "azurestorage45678"
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
resource "azurerm_virtual_machine_extension" "vm_mount" {
  name                 = var.vm_mount
  virtual_machine_id   = azurerm_windows_virtual_machine.vm["sp01-subnet1"].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<SETTINGS
  {
   "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.base64EncodedScript }')) | Out-File -filepath postBuild.ps1\" && powershell -ExecutionPolicy Unrestricted -File postBuild.ps1"
  }
  SETTINGS

  depends_on = [ azurerm_windows_virtual_machine.vm ]
}


#  #  connect to hub(Sp01 <--> Hub)

# data "azurerm_virtual_network" "hub_vnet" {
#   name ="hub_vnet"
#   resource_group_name = "hub_rg"
# }

# # Establish the Peering between Spoke_1 and Hub networks (Sp01 <--> Hub)
# resource "azurerm_virtual_network_peering" "Sp01-To-hub" {
#   name                      = "Sp01-To-hub"
#   resource_group_name       = azurerm_resource_group.sp_01rg.name
#   virtual_network_name      = azurerm_virtual_network.sp_01vnet["spoke_01_vnet"].name
#   remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet.id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = false
#   use_remote_gateways       = false
#   depends_on = [ azurerm_virtual_network.sp_01vnet , data.azurerm_virtual_network.hub_vnet  ]
# }
# # Establish the Peering between  Hub and Sp01 networks (Hub <--> Sp01)
# resource "azurerm_virtual_network_peering" "hub-To-Sp01" {
#   name                      = "hub-To-Sp01"
#   resource_group_name       = data.azurerm_virtual_network.hub_vnet.resource_group_name
#   virtual_network_name      = data.azurerm_virtual_network.hub_vnet.name
#   remote_virtual_network_id = azurerm_virtual_network.sp_01vnet["spoke_01_vnet"].id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = false
#   use_remote_gateways       = false
#   depends_on = [ azurerm_virtual_network.sp_01vnet , data.azurerm_virtual_network.hub_vnet ]
# }

```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azuread"></a> [azuread](#provider\_azuread)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) (resource)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_network_interface.nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_resource_group.sp_01rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_storage_account.stg-act](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_share.fileshare](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_network_security_group_association.nsgass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_virtual_machine_extension.vm_mount](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) (resource)
- [azurerm_virtual_network.sp_01vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_windows_virtual_machine.vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
- [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) (data source)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_Key_vault"></a> [Key\_vault](#input\_Key\_vault)

Description: Name of the Azure Key Vault

Type: `string`

### <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password)

Description: The Password of the User

Type: `string`

### <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username)

Description: The Username of the User

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

Description: The Location of the resource group

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the resource group

Type: `string`

### <a name="input_subnet_details"></a> [subnet\_details](#input\_subnet\_details)

Description: Map of subnet configurations

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

### <a name="input_vm_mount"></a> [vm\_mount](#input\_vm\_mount)

Description: Virtual machine mount name

Type: `string`

### <a name="input_vnet_details"></a> [vnet\_details](#input\_vnet\_details)

Description: Map of virtual network details

Type:

```hcl
map(object({
    vnet_name = string
    address_space = string
  }))
```

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: The name of CSV file containing NSG rules

Type: `string`

Default: `"rules.csv"`

## Outputs

The following outputs are exported:

### <a name="output_Key_Vault"></a> [Key\_Vault](#output\_Key\_Vault)

Description: n/a

### <a name="output_fileshare"></a> [fileshare](#output\_fileshare)

Description: n/a

### <a name="output_sp_01rg"></a> [sp\_01rg](#output\_sp\_01rg)

Description: n/a

### <a name="output_sp_01vnet"></a> [sp\_01vnet](#output\_sp\_01vnet)

Description: n/a

### <a name="output_subnet"></a> [subnet](#output\_subnet)

Description: n/a

### <a name="output_vm"></a> [vm](#output\_vm)

Description: n/a

## Modules

No modules.

<!-- END_TF_DOCS -->