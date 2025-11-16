# Quiz App Mini Version

#### **A simplified deployment of the Quiz App on a single EC2 instance using Docker Compose.**

Can be ran localy with docker compose, or a minimal deployment to AWS. 

---

## About The Quiz-app Project

The Quiz-app is a DevOps learning platform build by a DevOps student.
The app lets the user select a category, a sub-category and a difficulty, then generates a question about a random keyword in that subject. The user then answers the question, and recieves a score, and short feedback.

All the code is fully open source, and contains 5 main repositories:
- **[Frontend repository](https://github.com/liav-hasson/quiz-app-frontend.git)** - React frontend that runs on Nginx.
- **[Backend repository](https://github.com/liav-hasson/quiz-app-backend.git)** - Flask Python backend logic.
- **[GitOps repository](https://github.com/liav-hasson/quiz-app-gitops.git)** - ArgoCD App-of-app pattern.
- **[IaC repository](https://github.com/liav-hasson/quiz-app-iac.git)** - Terraform creates oll the base infrastructure, on AWS.
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

- **OpenAI API Key** - Must be created for querying. Follow the **[Official OpenAI Guide](https://platform.openai.com/docs/overview)** to create one.

### Configure Values
  
#### Set OpenAI API Key
   ```bash
   # Export the API key before running docker-compose
   export OPENAI_API_KEY=sk-your-key-here
   ```
   
* **Note:** If deploying via Terraform, the EC2 instance will need the key set either in its environment, passed via user-data or hard-coded to docker-compose.yml.

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
- Docker installation and container startup takes **2-3 minutes**
- Total time: **~4-5 minutes**

```bash
# Destroy all resources
terraform destroy
```
---

## Access the Application

### After deployment, Terraform outputs:

```
========================================
  Quiz App Mini Version Deployed!
========================================

Frontend: http://<PUBLIC_IP>:3000
Backend:  http://<PUBLIC_IP>:5000/api/health
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