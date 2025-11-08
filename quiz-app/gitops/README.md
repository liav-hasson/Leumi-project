# GitOps Repository - ArgoCD Configuration

This directory contains all Kubernetes manifests managed by ArgoCD using the **App-of-Apps** pattern. ArgoCD continuously syncs these configurations from Git to the EKS cluster, ensuring the desired state is always maintained.

## 📋 Repository Structure

```
gitops/
├── bootstrap/
│   └── root-app.yaml              # Root App-of-Apps (entry point)
├── applications/
│   ├── argocd-config.yaml         # ArgoCD UI TargetGroupBinding
│   ├── aws-load-balancer-controller.yaml
│   ├── external-secrets.yaml      # External Secrets Operator
│   ├── jenkins-platform.yaml      # Jenkins namespace, RBAC, BuildKit
│   └── quiz-app.yaml              # Quiz application deployment
├── argocd/
│   └── argocd-targetgroupbinding.yaml
├── jenkins-platform/
│   ├── Chart.yaml                 # Helm chart metadata
│   ├── values.yaml                # Jenkins platform configuration
│   └── templates/
│       ├── buildkit-daemonset.yaml
│       ├── buildkit-service.yaml
│       ├── clusterrolebinding.yaml
│       ├── docker-credentials-externalsecret.yaml
│       ├── namespace.yaml
│       ├── sa-token-secret.yaml
│       └── serviceaccount.yaml
└── quiz-app/
    ├── Chart.yaml                 # Helm chart metadata
    ├── values.yaml                # Quiz app configuration
    └── templates/
        ├── deployment.yaml        # Quiz app pods
        ├── service.yaml           # ClusterIP service
        ├── targetgroupbinding.yaml # AWS ALB integration
        ├── external-secrets.yaml   # OpenAI API key from SSM
        └── serviceaccount.yaml
```

---

## 🚀 Getting Started

### Prerequisites

1. **EKS Cluster** provisioned via Terraform (in `../iac/terraform/`)
2. **ArgoCD** installed on the cluster
3. **AWS Load Balancer Controller** (deployed by ArgoCD)
4. **External Secrets Operator** (deployed by ArgoCD)

### Deployment Process

The infrastructure is deployed in this order:

```
1. Terraform provisions EKS cluster + AWS resources
   ├── VPC, subnets, security groups
   ├── EKS cluster with node groups
   ├── ALB target groups
   ├── IAM roles (IRSA for ALB controller, External Secrets)
   └── Outputs: ARNs, IPs, DNS names

2. Terraform outputs are injected into GitOps manifests
   ├── values.yaml files updated with Terraform outputs
   ├── TargetGroupBinding ARNs
   ├── Security group IDs
   └── Changes pushed to GitHub

3. Root App-of-Apps is deployed to ArgoCD
   └── kubectl apply -f bootstrap/root-app.yaml

4. ArgoCD syncs all applications in order (sync waves)
   ├── Wave -1: External Secrets Operator, ALB Controller
   ├── Wave 0:  Jenkins Platform (namespace, RBAC, BuildKit)
   └── Wave 1:  Quiz App deployment
```

### Manual Bootstrap (if needed)

```bash
# 1. Apply root application (bootstraps everything)
kubectl apply -f bootstrap/root-app.yaml

# 2. Watch ArgoCD sync status
kubectl get applications -n argocd -w

# 3. Check application health
argocd app list
argocd app get root-app
argocd app get quiz-app
```

---

## 📦 Applications

### 1. Root App (bootstrap/root-app.yaml)

**Purpose:** The entry point that manages all other applications

**What it does:**
- Watches `gitops/applications/` directory
- Automatically creates child Application resources
- Implements App-of-Apps pattern

**Sync Policy:**
- Automated sync with prune and self-heal
- Creates namespaces automatically

---

### 2. AWS Load Balancer Controller (applications/aws-load-balancer-controller.yaml)

**Purpose:** Manages AWS Application Load Balancers from Kubernetes

**What it does:**
- Reconciles `TargetGroupBinding` resources
- Configures ALB listeners and target groups
- Integrates with AWS API via IRSA

**Sync Wave:** -1 (deployed first, required by quiz-app)

**Helm Chart:** `eks/aws-load-balancer-controller` v1.6.2

---

### 3. External Secrets Operator (applications/external-secrets.yaml)

**Purpose:** Syncs secrets from AWS SSM Parameter Store to Kubernetes Secrets

**What it does:**
- Installs External Secrets CRDs
- Enables IRSA authentication to AWS SSM
- Refreshes secrets automatically (1h interval)

**Sync Wave:** -1 (deployed first, required by quiz-app and jenkins)

**Secrets Managed:**
- `/devops-quiz/openai-api-key` → `quiz-app-secrets`
- `/weatherlabs/app/docker-registry-config` → `docker-config`

**Helm Chart:** `external-secrets/external-secrets` v0.9.20

---

### 4. Jenkins Platform (applications/jenkins-platform.yaml)

**Purpose:** Jenkins build agents infrastructure on EKS

**What it deploys:**
- `jenkins` namespace
- ServiceAccount with cluster-admin permissions
- Static ServiceAccount token (for Jenkins EC2 → EKS auth)
- BuildKit DaemonSet for Docker image builds
- Docker Hub credentials from External Secrets

**Components:**
- **Namespace:** Isolates Jenkins resources
- **ServiceAccount:** `jenkins` with cluster-admin RBAC
- **Secret:** `jenkins-token` (static token for EC2 Jenkins controller)
- **BuildKit:** Replaces Docker-in-Docker, builds and pushes images
- **ExternalSecret:** Docker Hub credentials from SSM

**Sync Wave:** 0 (after platform tools, before apps)

**Note:** Jenkins controller runs on EC2 (not in K8s), agents run as K8s pods

---

### 5. Quiz App (applications/quiz-app.yaml)

**Purpose:** Main application deployment

**What it deploys:**
- Quiz app pods (3 replicas)
- ClusterIP service
- TargetGroupBinding for ALB integration
- ExternalSecret for OpenAI API key

**Components:**
- **Deployment:** 3 replicas, liveness/readiness probes
- **Service:** ClusterIP on port 5000
- **TargetGroupBinding:** Routes ALB traffic to pods
- **ExternalSecret:** Injects OpenAI API key as env var
- **ClusterSecretStore:** AWS SSM Parameter Store access config

**Sync Wave:** 1 (after all dependencies)

**Image:** `liavvv/quiz-app:latest` (pushed by Jenkins pipeline)

---

### 6. ArgoCD Config (applications/argocd-config.yaml)

**Purpose:** Expose ArgoCD UI via ALB

**What it deploys:**
- TargetGroupBinding for ArgoCD server
- Routes ALB traffic to ArgoCD UI

---

## 🔐 Secret Management

### Architecture

The platform uses **External Secrets Operator** to sync secrets from AWS SSM Parameter Store.

```
AWS SSM Parameter Store    →    External Secrets Operator    →    Kubernetes Secrets
/devops-quiz/openai-api-key  →    ExternalSecret CRD          →    quiz-app-secrets
/weatherlabs/app/docker-*    →    ExternalSecret CRD          →    docker-config
```

### Secret Types

| Type | Resource | Purpose | Source |
|------|----------|---------|--------|
| **ClusterSecretStore** | `aws-parameter-store` | Defines HOW to access AWS SSM | Config only (IRSA) |
| **ExternalSecret** | `openai-api-key` | Quiz app API key | SSM: `/devops-quiz/openai-api-key` |
| **ExternalSecret** | `docker-registry-credentials` | Docker Hub auth | SSM: `/weatherlabs/app/docker-registry-config` |
| **Native Secret** | `jenkins-token` | Jenkins EC2 → EKS auth | ServiceAccount (K8s auto-generated) |

### Why This Design?

- ✅ **No secrets in Git:** All credentials stored in AWS SSM
- ✅ **GitOps-friendly:** ExternalSecret manifests tracked by ArgoCD
- ✅ **Automatic refresh:** Secrets synced every 1 hour
- ✅ **IRSA authentication:** No AWS keys needed (pod identity)
- ✅ **Separation of concerns:** App devs manage ExternalSecret, ops manage SSM

---

## 🔄 Sync Waves

ArgoCD deploys applications in order using sync waves:

| Wave | Applications | Purpose |
|------|-------------|---------|
| **-1** | External Secrets, ALB Controller | Platform dependencies |
| **0** | Jenkins Platform | Build infrastructure |
| **1** | Quiz App | Application workloads |

This ensures dependencies are ready before applications that need them.

---

## 🛠️ Helm Values Injection

Terraform outputs are automatically injected into Helm values by the `manage-project.sh` script:

```bash
# Terraform outputs
target_group_arn = "arn:aws:elasticloadbalancing:..."
alb_security_group_id = "sg-044452ce595e62972"

# Injected into gitops/quiz-app/values.yaml
targetGroupBinding:
  targetGroupARN: "arn:aws:elasticloadbalancing:..."
  networking:
    ingress:
      - from:
          - securityGroup:
              groupID: "sg-044452ce595e62972"
```

This keeps Terraform as the source of truth for infrastructure IDs.

---

## 📝 Common Operations

### View All Applications

```bash
# List all ArgoCD applications
kubectl get applications -n argocd

# Detailed view
argocd app list
```

### Sync an Application

```bash
# Manual sync
argocd app sync quiz-app

# Sync with force (recreate resources)
argocd app sync quiz-app --force

# Sync all applications
argocd app sync -l app.kubernetes.io/instance=root-app
```

### Check Application Status

```bash
# Get application details
argocd app get quiz-app

# Watch sync progress
argocd app get quiz-app --watch

# View application tree
argocd app resources quiz-app
```

### View Application Logs

```bash
# Quiz app logs
kubectl logs -n quiz-app -l app.kubernetes.io/name=quiz-app -f

# Jenkins BuildKit logs
kubectl logs -n jenkins -l app=buildkit -f

# ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

### Troubleshooting

```bash
# Check ArgoCD sync status
argocd app list

# Get sync errors
argocd app get quiz-app

# View last sync operation
kubectl describe application quiz-app -n argocd

# Check ExternalSecret status
kubectl get externalsecrets -A
kubectl describe externalsecret openai-api-key -n quiz-app

# Check if secrets are synced from SSM
kubectl get secrets -n quiz-app
kubectl get secret quiz-app-secrets -n quiz-app -o yaml
```

---

## 🏗️ Architecture Decisions

### Why App-of-Apps Pattern?

**Advantages:**
- ✅ Single entry point (`root-app.yaml`)
- ✅ Centralized dependency management via sync waves
- ✅ Easier to bootstrap new environments
- ✅ Git as single source of truth

**Compared to:**
- **Individual Applications:** Manual creation, no dependency ordering
- **ApplicationSets:** Better for multi-cluster/multi-tenant, overkill for single environment

### Why Helm Charts?

**Advantages:**
- ✅ Templating for environment-specific values
- ✅ Terraform outputs injected at deploy time
- ✅ Reusable across dev/staging/prod
- ✅ Standard packaging format

### Why External Secrets Operator?

**Advantages:**
- ✅ Secrets never in Git
- ✅ Automatic rotation (1h refresh)
- ✅ GitOps-friendly (ExternalSecret is a K8s resource)
- ✅ IRSA authentication (no AWS keys)

**Compared to:**
- **Sealed Secrets:** Encrypted secrets still in Git (key management complexity)
- **Manual Secrets:** No GitOps, no rotation, manual updates

---

## 🔗 Related Documentation

- [Infrastructure Terraform](../iac/terraform/README.MD) - AWS infrastructure provisioning
- [Management Scripts](../iac/scripts/README.md) - Deployment automation
- [Design Choices](../../docs/design-choice-argocd.txt) - Architecture decisions

---

## 📚 References

- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [External Secrets Operator](https://external-secrets.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
