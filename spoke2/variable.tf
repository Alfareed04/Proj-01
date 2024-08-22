

variable "resource_group_name" {
  type = string
  description = "The name of the resource group"
  validation {
    condition = length(var.resource_group_name)>0
    error_message = "The resource group name must not be empty"
  }
  
}

variable "resource_group_location" {
  type = string
  description = "The Location of the resource group"
  validation {
    condition = length(var.resource_group_location)>0
    error_message = "The resource group location must not be empty"
  }
  
}

variable "vnet_details" {
  type = map(object({
    vnet_name = string
    address_space = string
  }))
  description = "Map of virtual network details"
  validation {
    condition = length(var.vnet_details) > 0
    error_message = "At least one virtual network must be defined"
  }
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  description = "Map of subnet configurations"
  validation {
    condition = length(keys(var.subnet_details)) > 0
    error_message = "At least one subnet must be defined"
  }
}

variable "rules_file" {
  type = string
  description = "The name of CSV file containing NSG rules"
  default = "rules.csv"
}

# variable "admin_username" {
#   type = string
#   description = "The Username of the User"
# }

# variable "admin_password" {
#   type = string
#   description = "The Password of the User"
#   sensitive   = true
# }

