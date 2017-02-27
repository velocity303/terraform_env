resource "openstack_networking_router_v2" "router0" {
  name = "router0"
  external_gateway = "1c66e248-4fcb-405a-be75-821f85fc3ddb"
  admin_state_up = "true"
}

resource "openstack_networking_network_v2" "network0" {
  name = "infrastructure_network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet0" {
  name = "infrastructure_subnet"
  network_id = "${openstack_networking_network_v2.network0.id}"
  cidr = "192.168.1.0/24"
  ip_version = 4
  dns_nameservers = ["10.240.0.10", "10.240.1.10"]
}

resource "openstack_networking_router_interface_v2" "router_int_0" {
  router_id = "${openstack_networking_router_v2.router0.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet0.id}"
}

resource "openstack_networking_network_v2" "network1" {
  name = "chicago_network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet1" {
  name = "chicago_subnet"
  network_id = "${openstack_networking_network_v2.network1.id}"
  cidr = "192.168.2.0/24"
  ip_version = 4
  dns_nameservers = ["10.240.0.10", "10.240.1.10"]
}

resource "openstack_networking_router_interface_v2" "router_int_1" {
  router_id = "${openstack_networking_router_v2.router0.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet1.id}"
}

resource "openstack_networking_network_v2" "network2" {
  name = "portland_network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet2" {
  name = "portland_subnet"
  network_id = "${openstack_networking_network_v2.network2.id}"
  cidr = "192.168.3.0/24"
  ip_version = 4
  dns_nameservers = ["10.240.0.10", "10.240.1.10"]
}

resource "openstack_networking_router_interface_v2" "router_int_2" {
  router_id = "${openstack_networking_router_v2.router0.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet2.id}"
}
