# Quiz App Mini Version

#### **A simplified deployment of the Quiz App on a single EC2 instance using Docker Compose.**

**Use for testing and demonstrations only, not production ready!**
* Does NOT provide OpenAI API Key

---

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
  
#### Edit `docker-compose.yml`:
   ```yaml
   environment:
     - OPENAI_API_KEY=sk-your-key-here
     - OPENAI_MODEL=gpt-4o-mini # choose your model - gpt-4o-mini model is cheapest.
   ``` 

#### Optional: Edit `terraform.tfvars` to change defaults

```hcl
# AWS Region
aws_region = "eu-north-1"

# VPC Configurations
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidr   = "10.1.1.0/24"
availability_zone    = "eu-north-1a"

# EC2 configuration
instance_type = "t3.small" 
root_volume_size = 12 
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
Backend:  http://<PUBLIC_IP>:5000/health
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