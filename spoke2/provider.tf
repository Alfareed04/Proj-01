terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"           // Create a Resource Group using Terraform

      backend "azurerm" {
    resource_group_name  = "configuration_rg"
    storage_account_name = "stgacctconfig"
    container_name       = "container-config"
    key                  = "Sp02.tfstate"
  }
}
 
provider "azurerm" {
    features {}
}