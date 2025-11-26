
# =============================================================================
# AWS Configuration
# =============================================================================
aws_region = "eu-north-1"

# =============================================================================
# Project Settings
# =============================================================================
project_name = "quiz-mini"

# =============================================================================
# Network Configuration
# =============================================================================
vpc_cidr           = "10.1.0.0/16"
public_subnet_cidr = "10.1.1.0/24"
availability_zone  = "eu-north-1a"

# =============================================================================
# EC2 Configuration
# =============================================================================
instance_type    = "t3.small" # t3.micro for minimal cost, t3.medium for more resources
root_volume_size = 12         # GB - Increase if you need more storage

# MongoDB EBS volume from Kubernetes cluster
mongodb_ebs_volume_id = "vol-020cd08dcd3d4f91a"

# =============================================================================
# Route53 & SSL Configuration
# =============================================================================
public_zone_id = "Z06307832TD07PZVN77GO" # weatherlabs.org
domain_name    = "dev-quiz.weatherlabs.org"
enable_https   = true

# =============================================================================
# SSH Access
# =============================================================================
ssh_key_name = "test-key" # Replace with your AWS key pair name

# =============================================================================
# GitHub Repository (for cloning the app)
# =============================================================================
github_repo_url = "https://github.com/liav-hasson/quiz-app-mini.git"
github_branch   = "main"

# =============================================================================
# Resource Tags
# =============================================================================
common_tags = {
  Project     = "Quiz-Mini"
  Environment = "Development"
  ManagedBy   = "Terraform"
  Purpose     = "Ephemeral-Dev-Environment"
}
