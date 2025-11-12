#!/bin/bash
# =============================================================================
# EC2 User Data Script - Quiz App Mini Version
# =============================================================================
# This script runs automatically when the EC2 instance launches
# It installs Docker, pulls the repo, and starts the app with docker-compose

set -e  # Exit on any error

# =============================================================================
# Logging Function
# =============================================================================
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/quiz-app-setup.log
}

log "Starting Quiz App Mini setup..."

# =============================================================================
# 1. Update System Packages
# =============================================================================
log "Updating system packages..."
apt-get update -y

# =============================================================================
# 2. Install Git and Docker
# =============================================================================
log "Installing Git and Docker..."
apt-get install -y \
    git \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker service
systemctl start docker
systemctl enable docker

log "Docker installed successfully"

# =============================================================================
# 3. Clone Repository
# =============================================================================
log "Cloning quiz-app repository..."
cd /home/ubuntu

# injected from terraform.tfvars
git clone ${github_repo_url} quiz-app
cd quiz-app
git checkout ${github_branch}

# Set correct ownership
chown -R ubuntu:ubuntu /home/ubuntu/quiz-app

log "Repository cloned successfully"

# =============================================================================
# 4. Start Application with Docker Compose
# =============================================================================
log "Starting Quiz App with docker-compose..."
cd /home/ubuntu/quiz-app/mini-version

# Pull latest images
docker compose pull

# Start containers in detached mode
docker compose up -d

log "Docker Compose started successfully"

# =============================================================================
# 5. Wait for Services to be Healthy
# =============================================================================
log "Waiting for services to be healthy..."
sleep 30

# Check if containers are running
if docker ps | grep -q "quiz-backend"; then
    log "Backend container is running"
else
    log "Backend container failed to start"
fi

if docker ps | grep -q "quiz-frontend"; then
    log "Frontend container is running"
else
    log "Frontend container failed to start"
fi

# =============================================================================
# 6. Final Setup Complete
# =============================================================================
log "========================================="
log "Quiz App Mini setup complete!"
log "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
log "Backend:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000/health"
log "========================================="
log "Check logs: docker compose logs -f"
log "Check status: docker ps"
log "========================================="
