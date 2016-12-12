resource "openstack_compute_floatingip_v2" "myip" {
  pool = "ext-net-pdx1-opdx1"
}

resource "openstack_compute_instance_v2" "puppet" {
  count             = "1"
  name              = "puppet.${var.dclocation}.lab"
  image_name        = "centos_7_x86_64"
  image_id          = "5c509a1d-c7b2-4629-97ed-0d7ccd66e154"
  availability_zone = "opdx1"
  flavor_id         = "e1bc3af5-6798-44a0-bdae-ad03bc7ad357"
  flavor_name       = "m1.large"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "${var.tenant_network}"
    floating_ip = "${openstack_compute_floatingip_v2.myip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_puppetmaster.rendered}"
}

data "template_file" "init_puppetmaster" {
    template = "${file("bootstrap/bootstrap_puppetmaster.tpl")}"
    vars {
        control_repo         = "${var.puppet_control_repo}"
        location             = "${var.dclocation}"
        ssh_pri_key          = "${var.ssh_private_key}"
        ssh_pub_key          = "${var.ssh_public_key}"
        hostname             = "puppet"
    }
}
