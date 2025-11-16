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

# Add ubuntu user to docker group
usermod -aG docker ubuntu

log "Docker service started and ubuntu user added to docker group"

# Verify Docker installation
if docker --version &>/dev/null; then
    log "Docker installed successfully: $(docker --version)"
else
    log "ERROR: Docker installation failed"
    exit 1
fi

# Verify Docker Compose plugin
if docker compose version &>/dev/null; then
    log "Docker Compose installed successfully: $(docker compose version)"
else
    log "ERROR: Docker Compose plugin not found"
    exit 1
fi

# =============================================================================
# 3. Clone Repository
# =============================================================================
log "Cloning quiz-app repository from ${github_repo_url}..."
cd /home/ubuntu

# injected from terraform.tfvars
if git clone ${github_repo_url} quiz-app; then
    log "Repository cloned successfully"
else
    log "ERROR: Failed to clone repository"
    exit 1
fi

cd quiz-app
log "Checking out branch: ${github_branch}"
git checkout ${github_branch}

# Set correct ownership
chown -R ubuntu:ubuntu /home/ubuntu/quiz-app

log "Repository setup complete"

# =============================================================================
# 4. Start Application with Docker Compose
# =============================================================================
log "Starting application from quiz-app directory..."
cd /home/ubuntu/quiz-app

# Verify docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    log "ERROR: docker-compose.yml not found in $(pwd)"
    ls -la
    exit 1
fi

log "Found docker-compose.yml, pulling images..."
if docker compose pull; then
    log "Images pulled successfully"
else
    log "ERROR: Failed to pull images"
    exit 1
fi

log "Starting containers with docker compose up -d..."
# First attempt - MongoDB needs time to initialize with init scripts
if docker compose up -d; then
    log "Docker Compose started successfully"
else
    log "ERROR: Failed to start containers on first attempt"
    docker compose logs
    exit 1
fi

# =============================================================================
# 5. Wait for Services to be Healthy
# =============================================================================
log "Waiting for MongoDB to fully initialize (60 seconds)..."
sleep 60

# Check if all services are healthy, retry if needed
log "Checking service health and retrying if necessary..."
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    log "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."
    
    # Try to start all services
    docker compose up -d
    sleep 20
    
    # Check if all containers are running
    RUNNING_CONTAINERS=$(docker compose ps --filter "status=running" --format json 2>/dev/null | wc -l)
    
    if [ "$RUNNING_CONTAINERS" -ge 3 ]; then
        log "All services are running!"
        break
    else
        log "Some services not running yet (found $RUNNING_CONTAINERS/3), retrying..."
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log "WARNING: Not all services started after $MAX_RETRIES attempts"
fi

sleep 10

log "Checking container status..."
docker compose ps

# Check if containers are running
if docker ps | grep -q "quiz-backend"; then
    log "✅ Backend container is running"
else
    log "❌ Backend container failed to start"
    docker compose logs backend | tail -20
fi

if docker ps | grep -q "quiz-frontend"; then
    log "✅ Frontend container is running"
else
    log "❌ Frontend container failed to start"
    docker compose logs frontend | tail -20
fi

if docker ps | grep -q "quiz-mongodb"; then
    log "✅ MongoDB container is running"
else
    log "❌ MongoDB container failed to start"
    docker compose logs mongodb | tail -20
fi

# =============================================================================
# 6. Final Setup Complete
# =============================================================================
log "========================================="
log "Quiz App Mini setup complete!"
log "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
log "Backend:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000/api/health"
log "========================================="
log "Check logs: docker compose logs -f"
log "Check status: docker ps"
log "========================================="
