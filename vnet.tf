resource "random_pet" "lb_hostname" {}   # readable random word


resource "azurerm_virtual_network" "vnet" {
  name                = "greekvnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.greekrg.location
  resource_group_name = data.azurerm_resource_group.greekrg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "greeksubnet"
  resource_group_name  = data.azurerm_resource_group.greekrg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/20"]
}

# network security group for the subnet with a rule to allow http, https and ssh traffic
resource "azurerm_network_security_group" "NSG" {
  name                = "greekNSG"
  location            = data.azurerm_resource_group.greekrg.location
  resource_group_name = data.azurerm_resource_group.greekrg.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  #ssh security rule
  security_rule {
    name                       = "allow-ssh"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "NSG" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}


# A public IP address for the load balancer
resource "azurerm_public_ip" "LB-PIP" {
  name                = "lb-publicIP"
  location            = data.azurerm_resource_group.greekrg.location
  resource_group_name = data.azurerm_resource_group.greekrg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  domain_name_label   = lower("${data.azurerm_resource_group.greekrg.name}-${random_pet.lb_hostname.id}")
}

# A load balancer with a frontend IP configuration and a backend address pool
resource "azurerm_lb" "loadbalancer" {
  name                = "greekloadbalancer"
  location            = data.azurerm_resource_group.greekrg.location
  resource_group_name = data.azurerm_resource_group.greekrg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIP"
    public_ip_address_id = azurerm_public_ip.LB-PIP.id
  }
}

resource "azurerm_lb_backend_address_pool" "BEpool" {
  name            = "BackendAddressPool"
  loadbalancer_id = azurerm_lb.loadbalancer.id
 
}

#set up load balancer rule from azurerm_lb.loadbalancer frontend ip to azurerm_lb_backend_address_pool.BEpool backend ip port 80 to port 80
resource "azurerm_lb_rule" "LB-rule" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.loadbalancer.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIP"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.BEpool.id]
  probe_id                       = azurerm_lb_probe.loadbalancer.id
}

#set up load balancer probe to check if the backend is up
resource "azurerm_lb_probe" "loadbalancer" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.loadbalancer.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

#add lb nat rules to allow ssh access to the backend instances
resource "azurerm_lb_nat_rule" "ssh" {
  name                           = "ssh"
  resource_group_name            = data.azurerm_resource_group.greekrg.name
  loadbalancer_id                = azurerm_lb.loadbalancer.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIP"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.BEpool.id
}

resource "azurerm_public_ip" "natgwpip" {
  name                = "natgw-publicIP"
  location            = data.azurerm_resource_group.greekrg.location
  resource_group_name = data.azurerm_resource_group.greekrg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones                   = ["1"]
}

#add nat gateway to enable outbound traffic from the backend instances
resource "azurerm_nat_gateway" "natgw" {
  name                    = "nat-Gateway"
  location                = data.azurerm_resource_group.greekrg.location
  resource_group_name     = data.azurerm_resource_group.greekrg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

resource "azurerm_subnet_nat_gateway_association" "example" {
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

# add nat gateway public ip association
resource "azurerm_nat_gateway_public_ip_association" "natgw-association" {
  public_ip_address_id = azurerm_public_ip.natgwpip.id
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
}