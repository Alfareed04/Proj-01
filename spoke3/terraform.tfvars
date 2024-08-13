resource_group_name = "sp03_rg"
resource_group_location = "East us"

vnet_details={
    "sp03_vnet" ={
        vnet_name="sp03_vnet"
        address_space="10.50.0.0/16"
    }
}

subnet_details={
    "sp03-subnet" ={
        subnet_name ="sp03-subnet"
        address_prefix = "10.30.1.0/24"
    }
}

