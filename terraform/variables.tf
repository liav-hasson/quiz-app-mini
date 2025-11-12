# =============================================================================
# Mini Quiz App - Terraform Variables
# =============================================================================
# This file defines all configurable parameters for the ephemeral dev environment

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "quiz-mini"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnet"
  type        = string
  default     = "eu-north-1a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size of EC2 root volume in GB"
  type        = number
  default     = 12
}

variable "github_repo_url" {
  description = "GitHub repository URL to clone"
  type        = string
  default     = "https://github.com/liavweiss/quiz-app.git"
}

variable "github_branch" {
  description = "GitHub branch to checkout"
  type        = string
  default     = "main"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Quiz-Mini"
    Environment = "Development"
    ManagedBy   = "Terraform"
    Purpose     = "Ephemeral-Dev-Environment"
  }
}
