terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    "Name" = "Private Subnet-1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags = {
    "Name" = "Private Subnet-2"
  }
}

resource "aws_db_subnet_group" "db-subnet" {
  name       = "db-subnet-grp"
  subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
}

resource "random_password" "secret" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "db_secrets" {
  name        = "db-password"
  description = "DB credentials for the RDS Instance"
}

resource "aws_secretsmanager_secret_version" "db_secrets_value" {
  secret_id     = aws_secretsmanager_secret.db_secrets.id
  secret_string = random_password.secret.result
}

data "aws_secretsmanager_secret" "db_secrets" {
  name = "db-password"
  depends_on = [
    aws_secretsmanager_secret.db_secrets
  ]
}

data "aws_secretsmanager_secret_version" "db_secrets_value" {
  secret_id = data.aws_secretsmanager_secret.db_secrets.id
}


resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  identifier           = "test-db"
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "14.5"
  instance_class       = "db.t3.medium"
  db_name              = "endpoint-svc"
  username             = "endpoint-user"
  password             = aws_secretsmanager_secret_version.db_secrets_value.secret_id
  db_subnet_group_name = aws_db_subnet_group.db-subnet.name
  parameter_group_name = "postgres14"
}

