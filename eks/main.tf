terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "pipeline-vpc"
  }
}

resource "aws_subnet" "subnet_1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.0.0/20"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.16.0/26"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_subnet" "subnet_3" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.32.0/26"
  availability_zone = "us-east-1d"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-3"
  }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "pipeline-igw"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public-route-table"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw.id
  }
}

# Associate route table with each subnet
resource "aws_route_table_association" "public_subnet_assoc" {
  count          = 3
  subnet_id      = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id][count.index]
  route_table_id = aws_route_table.route_table.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "devops-pipeline-eks"
  cluster_version = "1.27"

  cluster_endpoint_public_access = true

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]

  eks_managed_node_groups = {
    green = {
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t2.medium"]
    }
  }
}