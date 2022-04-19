provider "aws" {
}

data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "qiime" {
  ami                    = data.aws_ami.latest_ubuntu.id
  instance_type          = var.type_of_instance
  key_name               = var.key_pair
  vpc_security_group_ids = [aws_security_group.main.id]
  root_block_device {
    volume_size = 50
  }
  user_data = <<EOF
#!/bin/bash
# Install docker
apt update -y
apt install docker.io -y
mkdir /opt/docker
echo "FROM quay.io/qiime2/core:2021.11" >> /opt/docker/Dockerfile
echo "RUN apt update -y" >> /opt/docker/Dockerfile
echo "RUN apt install unzip -y" >> /opt/docker/Dockerfile
chown -R ubuntu:ubuntu /opt/docker/
cd /opt/docker/
docker build -t qiime2 /opt/docker/
  EOF
}

resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
 ingress                = [
   {
     cidr_blocks      = [ "0.0.0.0/0", ]
     description      = ""
     from_port        = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 22
  }
  ]
}