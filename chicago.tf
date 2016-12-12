resource "openstack_compute_floatingip_v2" "fileserverchiip" {
  pool = "ext-net-pdx1-opdx1"
}

data "template_file" "init_fileserverchi" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "fileserver"
        name            = "fileserver.chicago.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}

resource "openstack_compute_instance_v2" "fileserverchi" {
  name              = "fileserverchi.chicago.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "d1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "network1"
    floating_ip = "${openstack_compute_floatingip_v2.fileserverchiip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_fileserverchi.rendered}"
}

