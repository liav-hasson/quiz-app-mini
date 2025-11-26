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
# 1. Mount MongoDB EBS Volume
# =============================================================================
log "Waiting for EBS volume to be attached..."
DEVICE_NAME="/dev/nvme1n1"  # NVMe naming on Nitro instances
MOUNT_POINT="/mnt/mongodb-data"
MAX_WAIT=60
ELAPSED=0

# Wait for NVMe device to appear
while [ ! -e "$DEVICE_NAME" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    log "Waiting for EBS volume to appear at $DEVICE_NAME... ($${ELAPSED}s elapsed)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ ! -e "$DEVICE_NAME" ]; then
    log "ERROR: EBS volume not found at $DEVICE_NAME after $${MAX_WAIT} seconds"
    exit 1
fi

log "Found NVMe device: $DEVICE_NAME"

# Create mount point
mkdir -p "$MOUNT_POINT"

# Check if volume is already formatted
if ! blkid "$DEVICE_NAME" > /dev/null 2>&1; then
    log "Volume not formatted. Formatting with ext4..."
    mkfs.ext4 "$DEVICE_NAME"
    log "Volume formatted successfully"
else
    log "Volume already formatted"
fi

# Mount the volume
log "Mounting EBS volume at $MOUNT_POINT..."
mount "$DEVICE_NAME" "$MOUNT_POINT"

# Add to fstab for persistence across reboots
UUID=$(blkid -s UUID -o value "$DEVICE_NAME")
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    log "Added volume to /etc/fstab"
fi

# Set permissions for Docker to access
chown -R 999:999 "$MOUNT_POINT"  # MongoDB container runs as UID 999
log "EBS volume mounted successfully at $MOUNT_POINT"

# =============================================================================
# 2. Update System Packages
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
# 5. Wait for MongoDB to be Ready
# =============================================================================
log "Waiting for MongoDB to be ready..."
MONGODB_CONTAINER="quiz-mongodb"
MAX_WAIT=300  # 5 minutes timeout
ELAPSED=0

until docker exec $MONGODB_CONTAINER mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        log "ERROR: MongoDB failed to start within $${MAX_WAIT} seconds"
        docker compose logs mongodb | tail -50
        exit 1
    fi
    log "Waiting for MongoDB to be ready... ($${ELAPSED}s elapsed)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

log "MongoDB is ready!"

# =============================================================================
# 6. Initialize MongoDB with Sample Data
# =============================================================================
log "Copying sample data and initialization script to MongoDB container..."

# Copy the data and script files
if docker cp /home/ubuntu/quiz-app/sample-data.json $${MONGODB_CONTAINER}:/tmp/sample-data.json; then
    log "✓ Copied sample-data.json"
else
    log "ERROR: Failed to copy sample-data.json"
    exit 1
fi

if docker cp /home/ubuntu/quiz-app/init-mongo.js $${MONGODB_CONTAINER}:/tmp/init-mongo.js; then
    log "✓ Copied init-mongo.js"
else
    log "ERROR: Failed to copy init-mongo.js"
    exit 1
fi

log "Running MongoDB initialization script..."
if docker exec $MONGODB_CONTAINER mongosh quizdb /tmp/init-mongo.js; then
    log "✓ MongoDB initialization completed successfully"
else
    log "ERROR: Failed to run initialization script"
    docker compose logs mongodb | tail -30
    exit 1
fi

# =============================================================================
# 7. Restart Backend to Ensure Connection
# =============================================================================
log "Restarting backend service to ensure proper MongoDB connection..."
docker compose restart backend
sleep 10

# =============================================================================
# 8. Verify All Services
# =============================================================================
log "Checking container status..."
docker compose ps

# Check if containers are running
if docker ps | grep -q "quiz-backend"; then
    log "Backend container is running"
else
    log "Backend container failed to start"
    docker compose logs backend | tail -20
fi

if docker ps | grep -q "quiz-frontend"; then
    log "Frontend container is running"
else
    log "Frontend container failed to start"
    docker compose logs frontend | tail -20
fi

if docker ps | grep -q "quiz-mongodb"; then
    log "MongoDB container is running"
else
    log "MongoDB container failed to start"
    docker compose logs mongodb | tail -20
fi

# =============================================================================
# 9. Final Setup Complete
# =============================================================================
log "========================================="
log "Quiz App Mini setup complete!"
log "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
log "Backend:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000/api/health"
log "========================================="
log "Check logs: docker compose logs -f"
log "Check status: docker ps"
log "========================================="
