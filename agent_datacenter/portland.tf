resource "openstack_compute_floatingip_v2" "fileserverpdxip" {
  pool = "ext-net-pdx1-opdx1"
}

resource "openstack_compute_floatingip_v2" "myapppdx" {
  pool = "ext-net-pdx1-opdx1"
}

data "template_file" "init_fileserverpdx" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "fileserver"
        name            = "fileserverpdx.portland.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}

data "template_file" "init_myapppdx" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "myapp"
        name            = "myapppdx.portland.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}

resource "openstack_compute_instance_v2" "fileserverpdx" {
  name              = "fileserverpdx.portland.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "d1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "network2"
    floating_ip = "${openstack_compute_floatingip_v2.fileserverpdxip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_fileserverpdx.rendered}"
}

resource "openstack_compute_instance_v2" "myapppdx" {
  name              = "myapppdx.portland.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "d1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "network1"
    floating_ip = "${openstack_compute_floatingip_v2.myapppdx.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_myapppdx.rendered}"
}

