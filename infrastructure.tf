resource "openstack_compute_floatingip_v2" "puppetip" {
  pool = "ext-net-pdx1-opdx1"
}

resource "openstack_compute_floatingip_v2" "jenkinsip" {
  pool = "ext-net-pdx1-opdx1"
}

resource "openstack_compute_floatingip_v2" "gitlabip" {
  pool = "ext-net-pdx1-opdx1"
}

resource "openstack_compute_floatingip_v2" "jenkins02ip" {
  pool = "ext-net-pdx1-opdx1"
}

resource "openstack_compute_floatingip_v2" "fileserverip" {
  pool = "ext-net-pdx1-opdx1"
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

data "template_file" "init_jenkinsmaster" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "jenkins_master"
        name            = "jenkins01.${var.dclocation}.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}

data "template_file" "init_jenkinsslave" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "jenkins_slave"
        name            = "jenkins02.${var.dclocation}.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}

data "template_file" "init_gitlab" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "gitlab"
        name            = "gitlab.${var.dclocation}.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}

data "template_file" "init_fileserver" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "fileserver"
        name            = "fileserver.${var.dclocation}.lab"
        master_name     = "${openstack_compute_instance_v2.puppet.name}"
        masterip        = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
    }
}


resource "openstack_compute_instance_v2" "puppet" {
  name              = "puppet.${var.dclocation}.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "m1.large"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "${var.tenant_network}"
    floating_ip = "${openstack_compute_floatingip_v2.puppetip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_puppetmaster.rendered}"
}

resource "openstack_compute_instance_v2" "jenkins" {
  name              = "jenkins01.${var.dclocation}.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "g1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "${var.tenant_network}"
    floating_ip = "${openstack_compute_floatingip_v2.jenkinsip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_jenkinsmaster.rendered}"
}

resource "openstack_compute_instance_v2" "jenkins_slave" {
  name              = "jenkins02.${var.dclocation}.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "g1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "${var.tenant_network}"
    floating_ip = "${openstack_compute_floatingip_v2.jenkins02ip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_jenkinsslave.rendered}"
}


resource "openstack_compute_instance_v2" "gitlab" {
  name              = "gitlab.${var.dclocation}.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "m1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "${var.tenant_network}"
    floating_ip = "${openstack_compute_floatingip_v2.gitlabip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_gitlab.rendered}"
}

resource "openstack_compute_instance_v2" "fileserver" {
  name              = "fileserver.${var.dclocation}.lab"
  image_name        = "centos_7_x86_64"
  availability_zone = "opdx1"
  flavor_name       = "d1.medium"
  key_pair          = "${var.openstack_keypair}"
  security_groups   = ["default", "sg0"]

  network {
    name = "${var.tenant_network}"
    floating_ip = "${openstack_compute_floatingip_v2.fileserverip.address}"
    access_network = true
  }

  user_data = "${data.template_file.init_fileserver.rendered}"
}

output "puppet_ip" {
  value = "${openstack_compute_instance_v2.puppet.network.0.fixed_ip_v4}"
}

output "puppet_host" {
  value = "${openstack_compute_instance_v2.puppet.name}"
}


