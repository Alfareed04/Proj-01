resource_group_name = "onpremise_rg"
location = "East us"

vnet_details={
    "onprem_vnet" ={
        vnet_name="onprem_vnet"
        address_space="10.10.0.0/16"
    }
}

subnet_details={
    "GatewaySubnet" ={
        subnet_name ="GatewaySubnet"
        address_prefix = "10.10.1.0/24"
    },
    "onprem-subnet" ={
        subnet_name = "onprem-subnet"
        address_prefix = "10.10.2.0/24"
    }
}

admin_username = "azureuser"
admin_password = "Helloazure0412"