variable "resource_group_name" {
  type = string
  default = "spoke01_rg"
}

variable "resource_group_location" {
  type = string
  default = "East US"
}

variable "virtual_network_name" {
    type = string
    default = "spoke_01_vnet"
}

variable "virtual_network_address_space" {
    type = string
    default = "10.30.0.0/16"
}

variable "subnet_details" {
    type = map(object({
      name = string
      address_prefix = string
    }))
    default = {
      "sp_01_subnet1" = {
        name = "sp_01_subnet1"
        address_prefix = "10.30.1.0/24"    //subnet1-nsg subnet-nsg
      },
      "sp_01_subnet2" = {
        name = "sp_01_subnet2"
        address_prefix = "10.30.2.0/24"   
      }

    }
  
}

variable "vm_count" {
  default = 2
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2"]
}

variable "admin_username" {
  type = string
  default = "azureuser"
}

variable "admin_password" {
  type = string
  default = "passwordazure12"
  sensitive = true
}