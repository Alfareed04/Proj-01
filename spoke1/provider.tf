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
    storage_account_name = "stgacctbackend01"
    container_name       = "stg-container-backend"
    key                  = "Sp01.tfstate"
  }
}
 
provider "azurerm" {
    features {}
}