terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


resource "tls_private_key" "pem-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key-pair" {
  key_name   = "bastion-key"
  public_key = tls_private_key.pem-key.public_key_openssh

  provisioner "local-exec" {
    command = <<-EOT
      echo "${tls_private_key.pem-key.private_key_pem}" > bastion-key.pem
      EOT
  }
}

resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "default-vpc"
  }
}

resource "aws_default_subnet" "default_subnet" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "default-subnet"
  }
}

resource "aws_security_group" "ec2-sg" {
  name        = "bastion-host-sg"
  description = "Allow SSH and DB traffic"
  vpc_id      = aws_default_vpc.default_vpc.id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion-host" {
  ami             = "ami-0aa7d40eeae50c9a9"
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.ec2-sg.name]
  key_name        = aws_key_pair.key-pair.key_name
  tags = {
    "Name" = "bastion-host"
  }
}