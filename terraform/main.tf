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

  # Allow HTTPS traffic
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
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
# Route53 Hosted Zone
# =============================================================================
# Reference existing hosted zone for DNS record creation
data "aws_route53_zone" "public" {
  zone_id = var.public_zone_id
}

# =============================================================================
# ACM Certificate for HTTPS
# =============================================================================
# Creates SSL certificate for the domain, validated via DNS
resource "aws_acm_certificate" "main" {
  count = var.enable_https ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-certificate"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation record for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_https ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public.zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "main" {
  count = var.enable_https ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
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
# IAM Role - EC2 Instance Role for SSM Parameter Store Access
# =============================================================================
# Allows EC2 to assume this role
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-ssm-role"
  }
}

# =============================================================================
# IAM Policy - SSM Parameter Store Read Access
# =============================================================================
# Grants permission to read parameters from SSM Parameter Store
resource "aws_iam_role_policy" "ssm_parameter_store_policy" {
  name = "${var.project_name}-ssm-parameter-store-policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# =============================================================================
# IAM Instance Profile - Attaches role to EC2
# =============================================================================
# Required to associate the IAM role with the EC2 instance
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Name = "${var.project_name}-ec2-ssm-profile"
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
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

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

# =============================================================================
# EBS Volume Attachment - MongoDB Data Volume
# =============================================================================
# Attaches the existing MongoDB EBS volume to the EC2 instance
resource "aws_volume_attachment" "mongodb_data" {
  device_name = "/dev/sdf"
  volume_id   = var.mongodb_ebs_volume_id
  instance_id = aws_instance.quiz_mini.id

  # Don't force detach on destroy to preserve data
  force_detach = false
  skip_destroy = true
}

# =============================================================================
# Route53 DNS Record
# =============================================================================
# Points domain name to EC2 instance public IP
resource "aws_route53_record" "quiz_mini" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.quiz_mini.public_ip]
}
