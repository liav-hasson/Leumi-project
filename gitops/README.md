# GitOps Directory Structure

This directory contains ArgoCD configurations for the DevOps Quiz Application deployment.

## Structure

```
gitops/
├── bootstrap/              # Initial ArgoCD setup
│   └── root-app.yaml      # App of Apps - manages all applications
├── applications/           # ArgoCD Application manifests
│   ├── aws-load-balancer-controller.yaml
│   ├── external-secrets.yaml
│   └── quiz-app.yaml
└── quiz-app/              # Helm chart for quiz application
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── _helpers.tpl
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        └── external-secrets.yaml
```

## Deployment Workflow

### 1. Initial Setup (One-time)

**Prerequisites:**
- EKS cluster created via Terraform (`iac/terraform/`)
- `kubectl` configured to access the cluster
- Helm 3 installed

**Install ArgoCD:**
```bash
# Use your existing installation script or:
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=ClusterIP \
  --set server.ingress.enabled=true
```

**Bootstrap all applications:**
```bash
kubectl apply -f gitops/bootstrap/root-app.yaml
```

This will automatically deploy:
- AWS Load Balancer Controller (for ALB/Ingress)
- External Secrets Operator (for SSM → K8s secrets)
- Quiz Application

### 2. Update IRSA Role ARNs

After Terraform apply, update the IRSA role ARNs from Terraform outputs:

```bash
# Get Terraform outputs
cd iac/terraform
terraform output alb_controller_role_arn
terraform output external_secrets_role_arn

# Update the application manifests:
# - applications/aws-load-balancer-controller.yaml
# - applications/external-secrets.yaml
```

### 3. Continuous Deployment

ArgoCD automatically syncs changes from Git:
- Commit changes to `gitops/` directory
- ArgoCD detects changes and syncs to cluster
- Jenkins pipeline updates `quiz-app` image tag

## Application Manifests

### aws-load-balancer-controller.yaml
Installs AWS Load Balancer Controller to manage ALB resources via Kubernetes Ingress objects.

**Key Configuration:**
- Cluster name: `devops-quiz-eks`
- Region: `eu-north-1`
- IRSA role: Must be updated with Terraform output

### external-secrets.yaml
Installs External Secrets Operator to sync secrets from AWS SSM Parameter Store.

**Key Configuration:**
- Syncs `/devops-quiz/openai-api-key` from SSM
- IRSA role: Must be updated with Terraform output

### quiz-app.yaml
Deploys the Flask quiz application using the Helm chart in `quiz-app/`.

**Key Configuration:**
- Namespace: `quiz-app`
- Helm chart path: `gitops/quiz-app`
- Image tag: Can be overridden by Jenkins pipeline

## Quiz App Helm Chart

### values.yaml Configuration

**Application:**
```yaml
app:
  name: quiz-app
  replicaCount: 2
  image:
    repository: REPLACE_WITH_ECR_REPO  # Update with your ECR URL
    tag: "latest"
```

**Ingress (ALB):**
```yaml
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
```

**External Secrets:**
```yaml
externalSecrets:
  enabled: true
  secrets:
    - name: openai-api-key
      key: /devops-quiz/openai-api-key  # SSM parameter path
```

## Jenkins Integration

Jenkins pipeline should:
1. Build Docker image from `src/python/`
2. Push to ECR
3. Update ArgoCD Application with new image tag:
   ```bash
   argocd app set quiz-app -p app.image.tag=v1.0.1
   # Or commit updated values.yaml to Git
   ```

## Monitoring ArgoCD

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Or access via ALB (once configured)
kubectl get ingress -n argocd
```

## Troubleshooting

**Application not syncing:**
```bash
argocd app sync <app-name>
argocd app get <app-name>
```

**External Secrets not working:**
```bash
kubectl get externalsecret -n quiz-app
kubectl describe externalsecret openai-api-key -n quiz-app
kubectl logs -n external-secrets-system deployment/external-secrets
```

**ALB not provisioned:**
```bash
kubectl get ingress -n quiz-app
kubectl describe ingress -n quiz-app
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```
