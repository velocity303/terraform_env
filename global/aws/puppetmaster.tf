module "ec2_master" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "puppetmaster-jj"

  ami                         = "ami-9fa343e7"
  instance_type               = "m3.xlarge"
  key_name                    = "james.jones-2"
  monitoring                  = false
  associate_public_ip_address = true
  subnet_id                   = "${aws_subnet.jamesjones-main.id}"
  vpc_security_group_ids      = ["${data.aws_security_group.default.id}", "${aws_security_group.allow_ssh.id}", "${aws_security_group.puppet_master.id}"]
  user_data                   = "${data.template_file.init_puppetmaster.rendered}"
}

data "template_file" "init_puppetmaster" {
  template = "${file("../scripts/setup_master.sh.tpl")}"

  vars {
    control_repo = "${var.puppet_control_repo}"
    ssh_pri_key  = "${var.ssh_private_key}"
    ssh_pub_key  = "${var.ssh_public_key}"
    license_key  = "${var.license_key}"
  }
}
