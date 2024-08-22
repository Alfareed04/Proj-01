resource_group_name = "spoke02_rg"
resource_group_location = "East us"

vnet_details={
    "spoke_02_vnet" ={
        vnet_name="spoke_02_vnet"
        address_space="10.40.0.0/16"
    }
}

subnet_details={
    "sp02-subnet1" ={
        subnet_name ="sp02-subnet1"
        address_prefix = "10.40.1.0/24"
    },
    "sp02-subnet2" ={
        subnet_name = "sp02-subnet2"
        address_prefix = "10.40.2.0/24"
    }
}

