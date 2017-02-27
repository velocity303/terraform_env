module "base_network" {
  source = "./networking"
}

module "puppet_master" {
  source = "./puppet_master"

  control_repo         = "${var.puppet_control_repo}"
  ssh_pri_key          = "${var.ssh_private_key}"
  ssh_pub_key          = "${var.ssh_public_key}"
}

module "jenkins_master" {
  source = "./linux_node"

  name = "jenkins01"
  role = "jenkins_master"
  location = "infrastructure"
  puppet_master_name = "puppet.infrastructure.lab"
  puppet_master_ip = "192.168.1.5"
}
