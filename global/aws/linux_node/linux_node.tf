variable "name" {
  description = "The name of the service you are running"
}

variable "role" {
  description = "The puppet role this particular machine will use"
}

variable "puppet_master_name" {
  description = "The fqdn of the puppet master"
}

variable "puppet_master_ip" {
  description = "The IP address of the puppet master"
}

variable "subnet_id" {
  description = "The id of the puppet master subnet"
}

variable "security_groups" {
  description = "The security groups for the node"
}




data "template_file" "init_node" {
    template = "${file("bootstrap/bootstrap_agent.tpl")}"
    vars {
        role            = "${var.role}"
        name            = "${var.name}.infrastructure.lab"
        master_name     = "${var.puppet_master_name}"
        masterip        = "${var.puppet_master_ip}"
    }
}

module "ec2_linux_node" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.name}"

  ami                         = "ami-9fa343e7"
  instance_type               = "t2.micro"
  key_name                    = "james.jones-2"
  monitoring                  = false
  associate_public_ip_address = true
  subnet_id                   = "${var.subnet_id}"
  vpc_security_group_ids      = "${var.security_groups}"
  user_data                   = "${data.template_file.init_node.rendered}"
}
