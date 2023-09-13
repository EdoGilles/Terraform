terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region     = "eu-west-3"
  access_key = "AKIA3EW7BRJBXKKYJ4HB"
  secret_key = "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"
}

############################################ VPC ############################################################
resource "aws_vpc" "default_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "Name" = "MyVPC"
  }
}

 ###################################### SUBNET PUBLIC#######################################################
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = "172.16.10.0/24"
  map_public_ip_on_launch = true
}

######################################### PRIVATE SUBNET ####################################################
resource "aws_subnet" "Private" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = "172.16.20.0/24"  # Utilisation d'une plage CIDR différente pour éviter un chevauchement avec la subnet public
}

############################################## ELASTIC IP ####################################################
resource "aws_eip" "ip_elastique" {
  domain = "vpc"
}

######################################### INTERNET GATEWAY ###################################################
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.default_vpc.id
  tags = {
    "Name" = "gwdefault"
  }
}

############################################ NAT GATEWAY #####################################################
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.ip_elastique.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.internet_gateway]
  tags = {
    "Name" = "gw_nat_public"
  }
}

############################################## ROUTE TABLE ###############################################
resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    "Name" = "table_route_1"
  }
}

resource "aws_route_table" "private_table" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    "Name" = "table_route_2"
  }
}

################################## ASSOCIATION DE TABLE ####################################################
resource "aws_route_table_association" "association_publique" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_table.id
}

resource "aws_route_table_association" "association_privee" {
  subnet_id      = aws_subnet.Private.id
  route_table_id = aws_route_table.private_table.id
}

######################################### SECURITY GROUP ###################################################
resource "aws_security_group" "http" {
  name        = "HTTP"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.default_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "HTTP Security Group"
  }
}

resource "aws_security_group" "ssh" {
  name        = "SSH"
  description = "Allow SSH traffic"
  vpc_id      = aws_vpc.default_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "SSH Security Group"
  }
}

########################################## CLES PUBLIQUE ##########################################
# resource "aws_key_pair" "deploiement_terraform" {
#   key_name   = "horus"
#   public_key = file("C:/Users/Gilles/Documents/5_SRC/Terraform/TP1/horus.pub")
# }

####################################### INSTANCE ###################################################
resource "aws_instance" "instance_publique" {
  instance_type = "t2.micro"
  ami           = "ami-05b5a865c3579bbc4"
  subnet_id     = aws_subnet.public.id
  key_name      = "webserver01_keys"
  security_groups = [aws_security_group.ssh.id, aws_security_group.http.id]
  
  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World foo" > index.html
    python3 -m http.server 8080 &
  EOF
}

resource "aws_instance" "instance_privee" {
  instance_type = "t2.micro"
  ami           = "ami-05b5a865c3579bbc4"
  subnet_id     = aws_subnet.Private.id
  #key_name      = "horus"
  security_groups = [aws_security_group.http.id]
  
  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World bar" > index.html
    python3 -m http.server 8080 &
  EOF
}
