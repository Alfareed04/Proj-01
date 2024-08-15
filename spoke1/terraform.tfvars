resource_group_name = "spoke01_rg"
location = "East us"

vnet_details={
    "spoke_01_vnet" ={
        vnet_name="spoke_01_vnet"
        address_space="10.30.0.0/16"
    }
}

subnet_details={
    "sp01-subnet1" ={
        subnet_name ="sp01-subnet1"
        address_prefix = "10.30.1.0/24"
    },
    "sp02-subnet2" ={
        subnet_name = "sp01-subnet2"
        address_prefix = "10.30.2.0/24"
    }
}

Key_vault = "proj0001keyvault"
admin_username = "azureuser"
admin_password = "Helloazure0412"
vm_mount = "mount-vm"