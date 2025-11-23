# Quiz App Mini Version

#### **A simplified deployment of the Quiz App on a single EC2 instance using Docker Compose.**

Can be ran localy with docker compose for personal use, or a minimal deployment to AWS.

## About The Quiz-app Project

The Quiz-app is a DevOps learning platform build by a DevOps student.
The app lets the user select a category, a sub-category and a difficulty, then generates a question about a random keyword in that subject. The user then answers the question, and recieves a score, and short feedback.

All the code is fully open source, and contains 5 main repositories:
- **[Frontend repository](https://github.com/liav-hasson/quiz-app-frontend.git)** - React frontend that runs on Nginx.
- **[Backend repository](https://github.com/liav-hasson/quiz-app-backend.git)** - Flask Python backend logic.
- **[GitOps repository](https://github.com/liav-hasson/quiz-app-gitops.git)** - ArgoCD App-of-app pattern.
- **[IaC repository](https://github.com/liav-hasson/quiz-app-iac.git)** - Terraform deploys all the base infrastructure to AWS.
- **[Mini-version repository](https://github.com/liav-hasson/quiz-app-mini.git) << You are here!** - Allows you to self-host localy, or on AWS.

## What Gets Deployed

This Terraform configuration creates:

- **VPC** with single public subnet and Internet Gateway
- **EC2 instance** (t3.small, Ubuntu 22.04)
- **Security Group** allowing inbound ports 3000 (frontend) and 5000 (backend)
- **3 Docker containers** automatically started:
  - `quiz-frontend` - React application (port 3000)
  - `quiz-backend` - Flask API (port 5000)
  - `quiz-mongodb` - MongoDB with seed data (port 27017)

---

## Before You Deploy

### Prerequisits

- **AWS Account** with permissions to create VPC, EC2, and Security Groups

   ```bash
   # AWS CLI configured with credentials
   aws configure
   
   # Terraform installed (v1.0+):
   terraform --version
   ```


> [!NOTE]  
> **OpenAI API Key** - Must be created for querying. Follow the **[Official OpenAI Guide](https://platform.openai.com/docs/overview)** to create one.


### Configure Values
  
- **Configurable values in docker-compose.yml**

   ```bash
    environment:
      # Flask configuration
      - FLASK_HOST=0.0.0.0
      - FLASK_PORT=5000
      - FLASK_DEBUG=false
      
      # MongoDB connection - points to mongodb container
      - MONGODB_HOST=mongodb
      - MONGODB_PORT=27017
      
      # Auto-migration disabled - user will manually load data after startup
      # In production K8s, this is set to false (mongodb-init Job handles data)
      - AUTO_MIGRATE_DB=false
      - REQUIRE_AUTHENTICATION=false
      
      # Optional auth/OAuth secrets (loaded from .env or shell)
      - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID:-}
      - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET:-}
      - JWT_SECRET=${JWT_SECRET:-}

      # Use your own API key
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}

      # Optional AI agent settings
      - OPENAI_MODEL=gpt-4o-mini
      - OPENAI_TEMPERATURE_QUESTION=${OPENAI_TEMPERATURE_QUESTION:-0.7}
      - OPENAI_TEMPERATURE_EVAL=${OPENAI_TEMPERATURE_EVAL:-0.5}
      - OPENAI_MAX_TOKENS_QUESTION=${OPENAI_MAX_TOKENS_QUESTION:-200}
      - OPENAI_MAX_TOKENS_EVAL=${OPENAI_MAX_TOKENS_EVAL:-300}
      - OPENAI_SSM_PARAMETER=${OPENAI_SSM_PARAMETER:-/devops-quiz/openai-api-key}
   ```
   
* **Note:** Edit the file directly or use a `.env` file to inject values into the containers. For sensitive values, consider using a secret manager.

#### Edit `terraform.tfvars` to change defaults

```hcl
# AWS Region
aws_region = "eu-north-1"

# VPC Configurations
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidr   = "10.1.1.0/24"
availability_zone    = "eu-north-1a"

# EC2 configurations
instance_type = "t3.small" 
root_volume_size = 12 

# SSH key configuration
ssh_key_name = "your-key-name"
```
---

## How to Deploy 

### Run on the Cloud

```bash
# Go to Terraform directory
cd /terraform

# Init the module 
terraform init

# Review what will be created
terraform plan

# Deploy the infrastructure
terraform apply -auto-approve
```

- Terraform completes in ~1 minute
- A local exec scripts will bootstrap docker and the initialize the database data **2-3 minutes**
- Total time: **~4-5 minutes**

```bash
# Destroy all resources
terraform destroy
```

---

### Run Locally

```bash
# Go to repo root directory
cd /mini-version

# Pull and run the images
docker compose pull
docker compose up -d

# Copy the DB and the script to the mongo container:
docker cp sample-data.json quiz-mongodb:/tmp/sample-data.json
docker cp init-mongo.js quiz-mongodb:/tmp/init-mongo.js

# Run the script:
docker exec quiz-mongodb mongosh quizdb /tmp/init-mongo.js
```

## Access the Application

### After deployment, Terraform outputs:

```
========================================
  Quiz App Mini Version Deployed!
========================================

Frontend: http://<PUBLIC_IP>:3000
SSH:      ssh -i ~/.ssh/<KEY_NAME>.pem ubuntu@<PUBLIC_IP>

========================================
```

### SSH Access

#### Connect to the EC2 instance to view logs or troubleshoot

```bash
ssh -i ~/.ssh/your-key-name.pem ubuntu@<PUBLIC_IP>

# Once connected, useful commands:
docker ps                           # Check running containers
docker compose logs -f              # View all container logs
docker compose logs backend -f      # View backend logs only
tail -f /var/log/quiz-app-setup.log # View EC2 user data setup logs
```