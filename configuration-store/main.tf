

resource "azurerm_resource_group" "rg" {
    name = var.resource_group_name
    location = var.location
}

resource "azurerm_storage_account" "stg" {
    name = var.storage_account_name
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    account_tier = "Standard"
    account_replication_type = "LRS"
    depends_on = [ azurerm_resource_group.rg ]
}

resource "azurerm_storage_container" "stg-cont" {
    name = var.container_name
    storage_account_name = azurerm_storage_account.stg.name
    container_access_type = "private"
}