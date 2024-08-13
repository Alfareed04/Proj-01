variable "resource_group_name" {
  type = string
  description = "The name of the Resource Group"
  validation {
    condition = length(var.resource_group_name)>0
    error_message = "The name must be provided"
  }

}

variable "resource_group_location" {
  type = string
  description = "The Location of the Resource Group"
  validation {
    condition = length(var.resource_group_location)>0
    error_message = "The Location must be provided"
  }
}

variable "vnet_details" {
  type = map(object({
    vnet_name = string
    address_space = string
  }))
  description = "The details of the VNET"
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  description = "The details of the Subnets"
}
