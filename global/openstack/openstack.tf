module "base_network" {
  source = "./networking"
}

module "puppet_master" {
  source = "./puppet_master"

  control_repo = "${var.puppet_control_repo}"
  ssh_pri_key  = "${var.ssh_private_key}"
  ssh_pub_key  = "${var.ssh_public_key}"
  license_key  = "${var.license_key}"
}

module "jenkins_master" {
  source = "./linux_node"

  name               = "jenkins01"
  role               = "jenkins_master"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "fileserver" {
  source = "./linux_node"

  name               = "fileserver"
  role               = "fileserver"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "gitlab" {
  source = "./linux_large_node"

  name               = "gitlab"
  role               = "gitlab"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "linuxnode01" {
  source = "./linux_node"

  name               = "linuxnode01"
  role               = "generic_website"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "linuxnode02" {
  source = "./linux_node"

  name               = "linuxnode02"
  role               = "generic_website"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "linuxnode03" {
  source = "./linux_node"

  name               = "linuxnode02"
  role               = "docker_host"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "winnode01" {
  source = "./windows_node"

  name               = "winnode01"
  role               = "generic_website"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "winnode02" {
  source = "./windows_node"

  name               = "winnode02"
  role               = "generic_website"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}

module "winnode03" {
  source = "./windows_node"

  name               = "winnode03"
  role               = "sqlserver"
  location           = "infrastructure"
  puppet_master_name = "${module.puppet_master.puppet_master_name}"
  puppet_master_ip   = "${module.puppet_master.puppet_master_ip}"
}
