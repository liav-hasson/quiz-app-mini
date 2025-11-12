# =============================================================================
# Mini Quiz App - Main Terraform Configuration
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# =============================================================================
# VPC - Virtual Private Cloud
# =============================================================================
# Creates an isolated network for our EC2 instance
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# =============================================================================
# Internet Gateway - Allows communication with the internet
# =============================================================================
# Required for EC2 to download Docker images and receive HTTP traffic
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =============================================================================
# Public Subnet - Network segment with internet access
# =============================================================================
# EC2 instance will be placed here to be publicly accessible
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true # Automatically assign public IP to instances

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# =============================================================================
# Route Table - Defines how network traffic is directed
# =============================================================================
# Routes all outbound traffic (0.0.0.0/0) through the Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# =============================================================================
# Route Table Association - Links route table to subnet
# =============================================================================
# Makes the public subnet actually use the route table above
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Security Group - Firewall rules for EC2
# =============================================================================
# Controls what traffic can reach the instance
resource "aws_security_group" "quiz_mini" {
  name        = "${var.project_name}-sg"
  description = "Security group for Quiz Mini EC2 instance"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP traffic to frontend
  ingress {
    description = "Frontend access"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP traffic to backend
  ingress {
    description = "Backend API access"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# =============================================================================
# Data Source - Get Latest Ubuntu AMI
# =============================================================================
# Automatically finds the most recent Ubuntu 22.04 LTS AMI in the region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu official)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# EC2 Instance - Main Application Server
# =============================================================================
# Runs Docker containers with frontend and backend
resource "aws_instance" "quiz_mini" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.quiz_mini.id]
  key_name               = var.ssh_key_name

  # User data script (runs on first boot)
  user_data = templatefile("${path.module}/user-data.sh", {
    github_repo_url = var.github_repo_url
    github_branch   = var.github_branch
  })

  # Root volume configuration
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # Enable detailed monitoring (optional, costs extra)
  monitoring = false

  tags = {
    Name = "${var.project_name}-instance"
  }
}
