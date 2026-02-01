# Deploying Remit-Radar to AWS: A Conceptual + Practical Guide

## 1. Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │           GitHub Actions             │
                    │  (CI/CD - builds, tests, deploys)    │
                    └──────┬──────────────┬───────────────┘
                           │              │
                    ┌──────▼─────┐  ┌─────▼──────────┐
                    │  S3 Bucket │  │  ECR Registry   │
                    │ (frontend  │  │ (Docker images  │
                    │  static)   │  │  for Rails)     │
                    └──────┬─────┘  └─────┬──────────┘
                           │              │
                    ┌──────▼─────┐  ┌─────▼──────────┐
                    │ CloudFront │  │  ECS Fargate    │
                    │   (CDN)    │  │ (Rails API)     │
                    └────────────┘  └─────┬──────────┘
                                          │
                                   ┌──────▼─────┐
                                   │  RDS        │
                                   │ (PostgreSQL)│
                                   └─────────────┘
```

| Service | Role | Why |
|---------|------|-----|
| **S3** | Hosts your Next.js static export (HTML/JS/CSS) | Cheap, scalable, no server needed for client-side apps |
| **CloudFront** | CDN in front of S3 | Fast global delivery, HTTPS, caching |
| **ECR** | Docker image registry | Stores your Rails Docker images (like Docker Hub but AWS-native) |
| **ECS Fargate** | Runs your Rails containers | Serverless containers — no EC2 instances to manage |
| **RDS** | Managed PostgreSQL | Automated backups, scaling, patching |
| **GitHub Actions** | CI/CD pipelines | Automates build → test → deploy on every push |
| **Terraform** | Infrastructure as Code | Defines all AWS resources in version-controlled files |

---

## 2. Concept: Terraform (Infrastructure as Code)

### What is Terraform?

Instead of clicking around the AWS console to create resources, you write `.tf` files that describe what you want. Terraform then creates/updates/destroys those resources for you.

### Core Concepts

**Providers** — Tell Terraform which cloud to talk to:

```hcl
# This is HCL (HashiCorp Configuration Language), not JSON or YAML
provider "aws" {
  region = "us-east-1"
}
```

**Resources** — The actual things you want to create:

```hcl
resource "aws_s3_bucket" "frontend" {
  bucket = "remit-radar-frontend"
}
```

The format is `resource "<provider>_<type>" "<local_name>"`. The local name is just for referencing it within your Terraform code.

**Variables** — Parameterize your config:

```hcl
variable "environment" {
  type    = string
  default = "production"
}

# Use it with var.<name>
resource "aws_s3_bucket" "frontend" {
  bucket = "remit-radar-frontend-${var.environment}"
}
```

**Outputs** — Values you want to see after `terraform apply`:

```hcl
output "frontend_url" {
  value = aws_cloudfront_distribution.frontend.domain_name
}
```

**State** — Terraform keeps a `terraform.tfstate` file that tracks what it has created. This maps your `.tf` files to real AWS resources. In a team, you store this in S3 (not locally) so everyone shares the same state.

**Data Sources** — Look up existing resources you didn't create with Terraform:

```hcl
data "aws_caller_identity" "current" {}
# Now data.aws_caller_identity.current.account_id gives your AWS account ID
```

### Key Commands

```bash
terraform init      # Downloads provider plugins, sets up backend
terraform plan      # Shows what WOULD change (dry run) — always run this first
terraform apply     # Actually creates/updates resources (asks for confirmation)
terraform destroy   # Tears down everything Terraform created
```

### How Terraform Works Internally

1. You write `.tf` files
2. `terraform plan` compares your `.tf` files against the state file
3. It computes a diff: "create X, update Y, delete Z"
4. `terraform apply` executes that diff via AWS API calls
5. State file is updated to reflect reality

**The golden rule:** Never manually change resources Terraform manages. If you do, Terraform's state drifts from reality and things break.

---

## 3. Concept: GitHub Actions (CI/CD)

### What is GitHub Actions?

Automation that runs when something happens in your repo (push, PR, tag, etc.). You define **workflows** in `.github/workflows/*.yml` files.

### Core Concepts

**Workflow** — A YAML file that defines an automated process. Lives in `.github/workflows/`.

**Event/Trigger** — What starts the workflow:

```yaml
on:
  push:
    branches: [main]        # Runs on push to main
  pull_request:
    branches: [main]        # Runs on PR targeting main
```

**Job** — A set of steps that run on a single runner (virtual machine). Jobs run in parallel by default:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest  # The VM image
    steps: [...]

  deploy:
    runs-on: ubuntu-latest
    needs: test              # "needs" makes this wait for "test" to pass
    steps: [...]
```

**Step** — A single command or action within a job:

```yaml
steps:
  - uses: actions/checkout@v4      # "uses" runs a pre-built action
  - run: npm install               # "run" executes a shell command
  - run: npm run build
```

**Actions** — Reusable units published by the community. `uses: actions/checkout@v4` clones your repo. `uses: aws-actions/configure-aws-credentials@v4` sets up AWS credentials. You don't write these — you use them.

**Secrets** — Encrypted variables stored in GitHub repo settings (Settings > Secrets and variables > Actions). Referenced as `${{ secrets.AWS_ACCESS_KEY_ID }}`. Never hardcode credentials.

**Environment variables and Context** — GitHub provides context objects:

```yaml
env:
  NODE_ENV: production

steps:
  - run: echo ${{ github.sha }}    # The commit hash
  - run: echo ${{ github.ref }}    # The branch/tag ref
```

### How a Typical CI/CD Pipeline Works

```
Push to main
    │
    ▼
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  Checkout    │────▶│  Build/Test   │────▶│   Deploy     │
│  code        │     │  (fail fast)  │     │  (only if    │
│              │     │               │     │   tests pass)│
└─────────────┘     └──────────────┘     └──────────────┘
```

---

## 4. Terraform: The Infrastructure

### 4.1 Project Structure

```
remit-radar/
├── infrastructure/
│   ├── main.tf              # Provider config, backend config
│   ├── variables.tf         # All input variables
│   ├── outputs.tf           # Values to export
│   ├── vpc.tf               # Network setup
│   ├── ecr.tf               # Container registry
│   ├── ecs.tf               # ECS cluster, service, task definition
│   ├── rds.tf               # PostgreSQL database
│   ├── s3.tf                # Frontend bucket
│   ├── cloudfront.tf        # CDN for frontend
│   ├── alb.tf               # Load balancer for ECS
│   ├── security_groups.tf   # Firewall rules
│   └── iam.tf               # Permissions
├── backend/
├── frontend/
└── .github/
    └── workflows/
        ├── frontend.yml
        └── backend.yml
```

### 4.2 main.tf — Provider and State Backend

```hcl
terraform {
  required_version = ">= 1.5"

  # Store state in S3 so it's shared and not lost
  backend "s3" {
    bucket = "remit-radar-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

**Why a remote backend?** If state is only on your laptop:

- Teammate runs `terraform apply` → they have no idea what exists → duplicates everything
- Laptop dies → you lose track of all infrastructure

You need to create this S3 bucket manually once (chicken-and-egg problem — Terraform can't store state in a bucket it hasn't created yet).

### 4.3 variables.tf

```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "remit-radar"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "db_username" {
  type      = string
  sensitive = true   # Won't show in plan output
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "rails_master_key" {
  type      = string
  sensitive = true
}
```

**How to pass sensitive variables:** Use a `terraform.tfvars` file (gitignored) or environment variables:

```bash
export TF_VAR_db_password="your-password"
terraform apply
```

### 4.4 vpc.tf — Networking

```hcl
# VPC = your own isolated network in AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # IP range: 10.0.0.0 - 10.0.255.255
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

# Public subnets — resources here get public IPs (ALB lives here)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-b" }
}

# Private subnets — no public IPs (ECS tasks and RDS live here)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"

  tags = { Name = "${var.project_name}-private-b" }
}

# Internet Gateway — lets public subnets reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                      # All traffic...
    gateway_id = aws_internet_gateway.main.id      # ...goes to internet
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway — lets private subnets reach the internet (for pulling Docker images)
# without being reachable FROM the internet
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id  # NAT lives in public subnet
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
```

**Why all this networking?**

Think of it like a building:

- **VPC** = the building itself (your isolated network)
- **Subnets** = floors (segments of the network)
- **Public subnets** = ground floor with a street entrance (internet-facing)
- **Private subnets** = basement floors with no street entrance (internal only)
- **Internet Gateway** = the front door
- **NAT Gateway** = a one-way window (private resources can see out, but nobody can see in)

RDS and ECS tasks go in private subnets for security. The ALB (load balancer) goes in public subnets because it needs to accept traffic from the internet.

**Why two subnets per type (a and b)?** AWS requires resources like RDS and ALB to span at least 2 availability zones for high availability. AZs are physically separate data centers in a region.

### 4.5 security_groups.tf — Firewall Rules

```hcl
# ALB security group — accepts HTTP/HTTPS from the internet
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"           # All traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS security group — only accepts traffic from the ALB
resource "aws_security_group" "ecs" {
  name   = "${var.project_name}-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # Only from ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS security group — only accepts traffic from ECS
resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432       # PostgreSQL port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]  # Only from ECS
  }
}
```

**The chain:** Internet → ALB (public) → ECS (private) → RDS (private). Each layer only talks to its neighbor. This is defense in depth.

### 4.6 ecr.tf — Container Registry

```hcl
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"  # Allows overwriting tags like "latest"

  # Auto-delete old untagged images to save storage costs
  image_scanning_configuration {
    scan_on_push = true  # Scans for vulnerabilities
  }
}

# Keep only last 10 images to save money
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
```

**What is ECR?** Think Docker Hub but private, inside your AWS account, and integrated with ECS. GitHub Actions will build your Docker image and push it here. ECS will pull from here to run your containers.

### 4.7 rds.tf — Database

```hcl
resource "aws_db_subnet_group" "main" {
  name = "${var.project_name}-db-subnet"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"    # Smallest instance, ~$15/month

  allocated_storage     = 20         # 20 GB
  max_allocated_storage = 50         # Auto-scale up to 50 GB

  db_name  = "remit_radar_production"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  backup_retention_period = 7        # Keep 7 days of automatic backups

  tags = { Name = "${var.project_name}-db" }
}
```

**Why RDS instead of running PostgreSQL in a container?** RDS handles automated backups, patching, failover, and monitoring. Running your own DB in ECS means you handle all of that yourself. For a production database, managed is almost always the right choice.

### 4.8 alb.tf — Load Balancer

```hcl
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false          # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # Required for Fargate

  health_check {
    path                = "/api/v1/health"  # You'll need to create this endpoint
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# For HTTPS, you'd add another listener with an ACM certificate:
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = aws_acm_certificate.main.arn
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.backend.arn
#   }
# }
```

**Why an ALB in front of ECS?** Fargate tasks are ephemeral — they can be replaced, scaled up/down, deployed to different IPs. You need a stable DNS entry that routes to whichever tasks are currently healthy. That's what the ALB does.

### 4.9 iam.tf — Permissions

```hcl
# ECS needs a role to pull images from ECR and write logs
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role — what your Rails app itself can do (e.g., access S3, send emails)
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}
```

**Execution role vs Task role:**

- **Execution role** = what ECS infrastructure needs (pull images, write logs). Used by the ECS agent.
- **Task role** = what your application code needs (access S3, SES, etc.). Used by your Rails process.

### 4.10 ecs.tf — The Rails Service

```hcl
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"    # 0.25 vCPU
  memory                   = "512"    # 512 MB
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = "${aws_ecr_repository.backend.repository_url}:latest"

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" },
      { name = "DATABASE_URL", value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/remit_radar_production" },
      { name = "RAILS_MASTER_KEY", value = var.rails_master_key },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.backend.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1             # Start with 1 task, scale later
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
    ]
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 80
  }

  # Allow ECS to drain old tasks during deployment
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}
```

**ECS Concepts:**

- **Cluster** = a logical grouping of services
- **Task Definition** = a blueprint (what image, how much CPU/memory, env vars). Like a `docker-compose.yml` entry.
- **Service** = keeps N copies of a task definition running. If one dies, it starts a new one.
- **Fargate** = you don't manage EC2 instances. AWS runs your container on shared infrastructure. You pay per second of vCPU/memory used.

### 4.11 s3.tf + cloudfront.tf — Frontend Hosting

```hcl
# --- s3.tf ---

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  # Block all public access — CloudFront will access via OAC
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}
```

```hcl
# --- cloudfront.tf ---

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  # SPA routing — return index.html for 404s so client-side routing works
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true  # Use custom ACM cert for your domain
  }
}
```

**Why CloudFront in front of S3?**

- S3 alone doesn't support HTTPS with a custom domain
- CloudFront caches your files at 400+ edge locations globally (fast loads worldwide)
- The S3 bucket stays private — only CloudFront can read from it (via OAC)

### 4.12 outputs.tf

```hcl
output "frontend_cloudfront_url" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "backend_alb_url" {
  value = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "rds_endpoint" {
  value     = aws_db_instance.postgres.endpoint
  sensitive = true
}
```

---

## 5. GitHub Actions: CI/CD Pipelines

### 5.1 Prerequisites in GitHub

Go to your repo > Settings > Secrets and variables > Actions > New repository secret. Add:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `RAILS_MASTER_KEY` | From `backend/config/master.key` |
| `CLOUDFRONT_DISTRIBUTION_ID` | From Terraform output |

### 5.2 Frontend Pipeline — `.github/workflows/frontend.yml`

```yaml
name: Frontend CI/CD

# TRIGGER: When does this run?
on:
  push:
    branches: [main]
    paths:
      - 'frontend/**'     # Only run when frontend code changes
  pull_request:
    branches: [main]
    paths:
      - 'frontend/**'

# PERMISSIONS: What can this workflow do?
permissions:
  id-token: write
  contents: read

jobs:
  # JOB 1: Lint and test
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./frontend   # All "run" steps execute here

    steps:
      # Step 1: Clone the repo
      - uses: actions/checkout@v4

      # Step 2: Set up Node.js with caching
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      # Step 3: Install dependencies
      # "npm ci" is like "npm install" but:
      # - Uses exact versions from package-lock.json
      # - Deletes node_modules first (clean install)
      # - Faster in CI because it skips resolution
      - run: npm ci

      # Step 4: Lint
      - run: npm run lint

  # JOB 2: Build and deploy (only on push to main, not on PRs)
  deploy:
    runs-on: ubuntu-latest
    needs: test                         # Wait for tests to pass
    if: github.event_name == 'push'     # Don't deploy on PRs
    defaults:
      run:
        working-directory: ./frontend

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - run: npm ci

      # Build static export
      - run: npm run build
        env:
          NEXT_PUBLIC_API_URL: https://api.your-domain.com  # Your ALB/API domain

      # Configure AWS credentials
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      # Sync build output to S3
      # --delete removes files from S3 that aren't in the build output
      # "out/" is the default Next.js static export directory
      - run: aws s3 sync out/ s3://remit-radar-frontend --delete

      # Invalidate CloudFront cache so users get the new version
      - run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

**Important: Next.js static export.** Since you're doing client-side API calls (no SSR), you need to configure Next.js for static export. In `frontend/next.config.ts`:

```ts
const nextConfig = {
  output: 'export',  // This makes "npm run build" produce static HTML/JS/CSS in "out/"
};
```

Without `output: 'export'`, Next.js produces a Node.js server — you can't host that on S3.

### 5.3 Backend Pipeline — `.github/workflows/backend.yml`

```yaml
name: Backend CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
  pull_request:
    branches: [main]
    paths:
      - 'backend/**'

permissions:
  id-token: write
  contents: read

jobs:
  # JOB 1: Test
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./backend

    # Services: spin up containers that your tests need
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: remit_radar_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    env:
      RAILS_ENV: test
      DATABASE_URL: postgresql://test_user:test_password@localhost:5432/remit_radar_test

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4.7'
          bundler-cache: true        # Caches gems based on Gemfile.lock
          working-directory: backend

      - run: bundle exec rails db:schema:load
      - run: bundle exec rspec

  # JOB 2: Build Docker image and deploy
  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push'
    defaults:
      run:
        working-directory: ./backend

    steps:
      - uses: actions/checkout@v4

      # Log in to ECR
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr-login

      # Build and push Docker image
      - name: Build and push
        env:
          ECR_REGISTRY: ${{ steps.ecr-login.outputs.registry }}
          ECR_REPOSITORY: remit-radar-backend
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:latest .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      # Deploy: update ECS service to use the new image
      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster remit-radar-cluster \
            --service remit-radar-backend \
            --force-new-deployment
```

**What happens during backend deploy:**

1. GitHub Actions builds a Docker image from your `backend/Dockerfile`
2. Tags it with the git commit SHA (so every deploy is traceable)
3. Pushes to ECR
4. Tells ECS to do a new deployment
5. ECS pulls the new image, starts new task(s), health checks pass, drains old task(s)
6. Zero-downtime deployment because the ALB only routes to healthy tasks

### 5.4 The Deploy Flow Visualized

```
Developer pushes to main
         │
         ▼
GitHub Actions triggers
         │
    ┌────┴────┐
    ▼         ▼
 frontend/  backend/
 changed?   changed?
    │         │
    ▼         ▼
  Lint      RSpec
  Test      Tests
    │         │
    ▼         ▼
npm build   docker build
    │         │
    ▼         ▼
S3 sync    ECR push
    │         │
    ▼         ▼
CloudFront  ECS force
invalidate  new deploy
    │         │
    ▼         ▼
  LIVE!     LIVE!
```

---

## 6. Step-by-Step: Getting This Running

### Phase 1: AWS Account Setup

1. Create an AWS account if you don't have one
2. Create an IAM user for CI/CD with programmatic access
3. Attach policies: `AmazonECS_FullAccess`, `AmazonEC2ContainerRegistryFullAccess`, `AmazonS3FullAccess`, `CloudFrontFullAccess`, `AmazonVPCFullAccess`, `AmazonRDSFullAccess`, `ElasticLoadBalancingFullAccess`, `CloudWatchLogsFullAccess`, `IAMFullAccess`
4. Save the access key and secret key

### Phase 2: Terraform State Bucket (one-time manual step)

```bash
aws s3api create-bucket \
  --bucket remit-radar-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket remit-radar-terraform-state \
  --versioning-configuration Status=Enabled
```

### Phase 3: Run Terraform

```bash
cd infrastructure/

# Create terraform.tfvars (gitignored!)
cat > terraform.tfvars <<EOF
db_username      = "remit_radar_admin"
db_password      = "a-strong-password-here"
rails_master_key = "your-master-key-from-backend/config/master.key"
EOF

terraform init     # Download AWS provider, connect to state bucket
terraform plan     # Review what will be created
terraform apply    # Create everything (type "yes" to confirm)
```

### Phase 4: Initial Docker Image Push (one-time)

ECS can't start if there's no image in ECR yet:

```bash
# Log in to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push
cd backend/
docker build -t remit-radar-backend .
docker tag remit-radar-backend:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/remit-radar-backend:latest
docker push \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/remit-radar-backend:latest
```

### Phase 5: Run Database Migrations

```bash
# Use ECS exec to run a one-off command in a running task
aws ecs execute-command \
  --cluster remit-radar-cluster \
  --task <task-id> \
  --container backend \
  --interactive \
  --command "/bin/bash -c 'bundle exec rails db:migrate'"
```

### Phase 6: Configure GitHub Secrets and Push

Add all secrets in GitHub (see section 5.1), then push to main. The workflows will handle everything from there.

### Phase 7: Configure Next.js for Static Export

Add `output: 'export'` to your `next.config.ts` and set `NEXT_PUBLIC_API_URL` to point to your ALB domain.

---

## 7. Key Things to Remember

### Terraform

- Never edit AWS resources manually after Terraform manages them
- Always run `terraform plan` before `apply`
- Keep `terraform.tfvars` and `.tfstate` out of git
- Use `terraform destroy` to clean up when experimenting (avoids surprise bills)

### GitHub Actions

- `paths` filter avoids running frontend pipeline when only backend changes (and vice versa)
- `needs` creates job dependencies (deploy waits for test)
- `if: github.event_name == 'push'` prevents deploying on PRs
- Cache aggressively (node_modules, gems) — CI is slow without caching

### Cost Awareness

| Resource | Approximate Monthly Cost |
|----------|--------------------------|
| NAT Gateway | ~$32 (the most expensive "hidden" cost) |
| RDS db.t3.micro | ~$15 |
| ECS Fargate (256 CPU / 512 MB) | ~$10 |
| ALB | ~$16 base |
| S3 + CloudFront | Cents unless massive traffic |

**To reduce costs for learning/dev:**

- Skip NAT Gateway and put ECS in public subnets (less secure but free)
- Use RDS free tier (db.t3.micro, 750 hours/month free for 12 months)
