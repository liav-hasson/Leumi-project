# Leumi Project - DevOps Quiz Application

## Overview
This project deploys a Flask-based quiz application to Amazon EKS using Jenkins CI/CD pipeline and ArgoCD for GitOps.

### Architecture
- **Application**: Flask quiz app (Python) in `src/` directory
- **Jenkins Controller**: EC2 instance (accessed via SSM)
- **Jenkins Agents**: Kubernetes pods running on EKS cluster
- **ArgoCD**: GitOps tool running on EKS for automated deployments
- **Load Balancing**: AWS Application Load Balancer (ALB) for HTTPS access
- **Git Provider**: GitHub (monorepo - application code + GitOps manifests)

### Key Components
- **Application Code**: Flask quiz application in `src/python/`
- **Infrastructure as Code**: Terraform modules in `iac/terraform/`
- **GitOps Manifests**: ArgoCD/Helm configurations in `gitops/`
- **CI/CD Pipeline**: Jenkins pipeline in `Jenkinsfile`

## Repository Structure
```
├── src/                    # Quiz application source code
│   ├── python/            # Flask application
│   ├── templates/         # HTML templates
│   ├── static/            # CSS/JS assets
│   └── requirements.txt   # Python dependencies
├── iac/
│   └── terraform/          # Infrastructure as Code
│       ├── modules/        # Reusable Terraform modules
│       │   ├── vpc/       # VPC, subnets, NAT
│       │   ├── iam/       # IAM roles and policies
│       │   ├── security-groups/  # Security groups
│       │   └── ec2/       # EC2 instances (Jenkins)
│       └── prod_cluster/   # EKS cluster configuration
├── gitops/                 # GitOps manifests
│   ├── bootstrap-prod/     # Bootstrap infrastructure (ArgoCD, ALB controller)
│   └── applications/       # Application deployments
├── Jenkinsfile             # CI/CD pipeline definition
└── MIGRATION_TASKS.md      # Project migration tracking

```

## Infrastructure Components

### AWS Resources
- **VPC**: Custom VPC with public/private subnets across 3 AZs
- **EKS Cluster**: Production Kubernetes cluster for running applications
- **Jenkins Controller**: EC2 instance for CI/CD orchestration
- **Security Groups**: Network access control for Jenkins and Kubernetes
- **IAM Roles**: IRSA for EKS workloads (ArgoCD, ALB controller, External Secrets)

### Kubernetes Resources
- **ArgoCD**: GitOps continuous delivery tool
- **AWS Load Balancer Controller**: Manages ALB for ingress
- **External Secrets Operator**: Syncs secrets from AWS SSM/Secrets Manager
- **Jenkins Agents**: Dynamic pods for building and testing

## Getting Started

### Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.5
- kubectl
- AWS CLI configured
- GitHub repository access

### Deployment Steps
1. **Configure Terraform variables** (create `terraform.tfvars`)
2. **Deploy infrastructure** with Terraform
3. **Bootstrap EKS cluster** with ArgoCD and supporting tools
4. **Configure Jenkins** controller with EKS credentials
5. **Deploy application** via Jenkins pipeline

## Status
🚧 **In Progress**: Migrating infrastructure from previous project to support quiz app deployment.

See `MIGRATION_TASKS.md` for detailed progress tracking.