resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                        = "vmss-terraform"
  resource_group_name         = data.azurerm_resource_group.greekrg.name
  location                    = data.azurerm_resource_group.greekrg.location
  sku_name                    = "Standard_D2s_v4"
  instances                   = 3
  platform_fault_domain_count = 1     # For zonal deployments, this must be set to 1
  zones                       = ["1"] # Zones required to lookup zone in the startup script

  user_data_base64 = base64encode(file("greek-data.sh"))
  os_profile {
    linux_configuration {
      disable_password_authentication = true
      admin_username                  = "greekgod"
      admin_ssh_key {
        username   = "greekgod"
        public_key = file(".ssh/key.pub")
      }
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-LTS-gen2"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name                          = "nic"
    primary                       = true
    enable_accelerated_networking = false

    ip_configuration {
      name                                   = "ipconfig"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.BEpool.id]
    }
  }

  boot_diagnostics {
    storage_account_uri = ""
  }

  # Ignore changes to the instances property, so that the VMSS is not recreated when the number of instances is changed
  lifecycle {
    ignore_changes = [
      instances
    ]
  }
}