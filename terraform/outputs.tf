# =============================================================================
# Mini Quiz App - Terraform Outputs
# =============================================================================
# These outputs display important information after deployment

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.quiz_mini.public_ip
}

output "frontend_url" {
  description = "URL to access the Quiz App frontend"
  value       = "http://${aws_instance.quiz_mini.public_ip}:3000"
}

output "backend_url" {
  description = "URL to access the Quiz App backend API"
  value       = "http://${aws_instance.quiz_mini.public_ip}:5000"
}

output "backend_health" {
  description = "Backend health check endpoint"
  value       = "http://${aws_instance.quiz_mini.public_ip}:5000/health"
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.quiz_mini.public_ip}"
}

output "deployment_status" {
  description = "Information about deployment"
  value       = <<-EOT
  
  ========================================
    Quiz App Mini Version Deployed!
  ========================================
  
  Frontend: http://${aws_instance.quiz_mini.public_ip}:3000
  Backend:  http://${aws_instance.quiz_mini.public_ip}:5000/health
  SSH:      ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.quiz_mini.public_ip}
  
  Note: It may take 2-3 minutes for Docker containers to start.
  View setup logs: Check EC2 user data logs in AWS Console
  
  ========================================
  EOT
}
