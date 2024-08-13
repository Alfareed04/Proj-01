resource_group_name = "hub_rg"
resource_group_location = "East us"

vnet_details={
    "hub_vnet" ={
        vnet_name="hub_vnet"
        address_space="10.20.0.0/16"
    }
}

subnet_details={
    "AzureFirewallSubnet" ={
        subnet_name ="AzureFirewallSubnet"
        address_prefix = "10.20.1.0/24"
    },
    "GatewaySubnet" ={
        subnet_name = "GatewaySubnet"
        address_prefix = "10.20.2.0/24"
    }
    "AzureBastionSubnet" = {
      subnet_name = "AzureBastionSubnet"
      address_prefix = "10.20.3.0/24"
    }
}
