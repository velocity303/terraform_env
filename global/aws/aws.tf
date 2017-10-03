module "vpc" {
  source                  = "terraform-aws-modules/vpc/aws"
  name                    = "jamesjones-vpc"
  cidr                    = "10.10.0.0/16"
  enable_nat_gateway      = true
  map_public_ip_on_launch = true
  enable_dns_hostnames    = true
  enable_dns_support      = true
}

resource "aws_subnet" "jamesjones-main" {
  vpc_id                  = "${data.aws_vpc.jamesjones-vpc.id}"
  cidr_block              = "10.10.0.0/16"
  map_public_ip_on_launch = true

  tags {
    Name = "Main"
  }
}

resource "aws_internet_gateway" "jamesjones-gw" {
  vpc_id = "${data.aws_vpc.jamesjones-vpc.id}"

  tags {
    Name = "main"
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${data.aws_vpc.jamesjones-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.jamesjones-gw.id}"
  }

  tags {
    Name = "default table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.jamesjones-main.id}"
  route_table_id = "${aws_route_table.r.id}"
}

data "aws_vpc" "jamesjones-vpc" {
  id = "${module.vpc.vpc_id}"
}

data "aws_security_group" "default" {
  vpc_id = "${data.aws_vpc.jamesjones-vpc.id}"
  name   = "default"
}

/*
module "ec2_cluster" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name  = "my-cluster"
  count = 2

  ami                    = "ami-9fa343e7"
  instance_type          = "t2.micro"
  key_name               = "james.jones-1"
  monitoring             = false
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.jamesjones-main.id}"
  vpc_security_group_ids = ["${data.aws_security_group.default.id}", "${aws_security_group.allow_ssh.id}"]
}
*/

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = "${data.aws_vpc.jamesjones-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "puppet_master" {
  name        = "puppet_master"
  description = "Allow puppet inbound traffic"
  vpc_id      = "${data.aws_vpc.jamesjones-vpc.id}"

  ingress {
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 61613
    to_port     = 61613
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8142
    to_port     = 8142
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_puppetmaster"
  }
}

module "jenkins_master" {
  source = "./linux_node"

  name = "jenkins01"
  role = "jenkins_master"
  subnet_id  = "${aws_subnet.jamesjones-main.id}"
  security_groups      = ["${data.aws_security_group.default.id}", "${aws_security_group.allow_ssh.id}"]
  puppet_master_name = "puppet.infrastructure.lab"
  puppet_master_ip = "${module.ec2_master.private_ip}"
}
