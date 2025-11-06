# Script Automation Gap Analysis

## Overview
Analysis of what's **NOT automated** in the current scripts after our fixes.

---

## Current Workflow (What Scripts Do)

### ✅ Automated Steps

1. **Terraform Deployment** (`terraform.sh`)
   - ✅ terraform init
   - ✅ terraform apply -auto-approve
   - ✅ Real-time output display
   - ✅ Logging to files

2. **Kubectl Configuration** (`terraform.sh`)
   - ✅ aws eks update-kubeconfig
   - ✅ Switch context to EKS cluster
   - ✅ Verify cluster access

3. **Logging** (`common.sh`, `logging-helpers.sh`)
   - ✅ Structured logs to /tmp/quiz-app-deploy/
   - ✅ Separate log files per component
   - ✅ Deployment summary

4. **Access Information** (`project-utils.sh`)
   - ✅ Display cluster access info
   - ✅ Show ArgoCD credentials
   - ✅ List service URLs

---

## ❌ NOT AUTOMATED - Manual Steps Required

### 1. **Injection Script** (CRITICAL - Referenced but Missing)

**Status**: ❌ **DOES NOT EXIST**

**Current Issue**:
```bash
# In apply.sh line 13:
source "$LIB_ROOT/apply/inject-argocd-values.sh"  # ← FILE DOES NOT EXIST

# In workflow.sh line 28:
inject_terraform_values "$operation"  # ← FUNCTION DOES NOT EXIST
```

**What It Should Do**:
```bash
# Fetch terraform outputs
EKS_CLUSTER_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw eks_cluster_name)
ALB_CONTROLLER_ROLE_ARN=$(cd "$TERRAFORM_DIR" && terraform output -raw alb_controller_role_arn)
EXTERNAL_SECRETS_ROLE_ARN=$(cd "$TERRAFORM_DIR" && terraform output -raw external_secrets_role_arn)
AWS_REGION=$(cd "$TERRAFORM_DIR" && terraform output -raw region)
CERTIFICATE_ARN=$(cd "$TERRAFORM_DIR" && terraform output -raw acm_certificate_arn)
VPC_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw vpc_id)

# Update GitOps values files
# Option 1: Using yq (requires yq installation)
yq eval -i ".aws.region = \"$AWS_REGION\"" "$GITOPS_DIR/quiz-app/values.yaml"
yq eval -i ".ingress.annotations[\"alb.ingress.kubernetes.io/certificate-arn\"] = \"$CERTIFICATE_ARN\"" "$GITOPS_DIR/quiz-app/values.yaml"

# Option 2: Using sed (no dependencies)
sed -i "s|region:.*|region: $AWS_REGION|g" "$GITOPS_DIR/quiz-app/values.yaml"
sed -i "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: $CERTIFICATE_ARN|g" "$GITOPS_DIR/quiz-app/values.yaml"
```

**Files to Update**:
- `pipeline/gitops/quiz-app/values.yaml` - Certificate ARN, region
- `pipeline/gitops/applications/aws-load-balancer-controller.yaml` - VPC ID, cluster name
- `pipeline/gitops/applications/external-secrets.yaml` - Region, IRSA role
- `pipeline/gitops/applications/quiz-app.yaml` - Cluster name

**Manual Workaround**:
```bash
# Get outputs
cd pipeline/iac/terraform
terraform output

# Manually edit:
vi pipeline/gitops/quiz-app/values.yaml
# Update certificate ARN, region, etc.
```

---

### 2. **Git Commit & Push** (Currently Manual)

**Status**: ❌ **NOT AUTOMATED**

**Current Workflow**:
```bash
# User must manually:
cd pipeline/gitops
git add .
git commit -m "Update values from terraform outputs"
git push origin main
```

**What Automation Would Look Like**:
```bash
apply_push_gitops_changes() {
    local gitops_dir="$GITOPS_DIR"
    
    cd "$gitops_dir"
    
    # Check if there are changes
    if [[ -n $(git status --porcelain) ]]; then
        log_message "Committing GitOps changes..."
        
        git add values.yaml applications/*.yaml
        git commit -m "chore: Update ArgoCD values from terraform outputs [automated]

Terraform outputs injected:
- EKS cluster: $EKS_CLUSTER_NAME
- ACM certificate: $CERTIFICATE_ARN
- AWS region: $AWS_REGION
- ALB Controller IRSA: $ALB_CONTROLLER_ROLE_ARN
- External Secrets IRSA: $EXTERNAL_SECRETS_ROLE_ARN"
        
        # Push to remote
        git push origin main || {
            log_error "Failed to push GitOps changes"
            log_warning "Please push manually: cd $gitops_dir && git push"
            return 1
        }
        
        log_message "✓ GitOps changes pushed to GitHub"
    else
        log_message "No GitOps changes to commit"
    fi
}
```

**Why Not Automated**:
- Requires git credentials (SSH key or PAT)
- User may want to review changes before committing
- Could break if git not configured
- Security concern: automated commits need auth

---

### 3. **ArgoCD Bootstrap Deployment** (Currently Manual)

**Status**: ❌ **NOT AUTOMATED**

**Current Workflow**:
```bash
# User must manually:
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --wait

# Then apply root app
kubectl apply -f pipeline/gitops/bootstrap/root-app.yaml
```

**What Automation Would Look Like**:
```bash
apply_deploy_argocd_bootstrap() {
    local operation="$1"
    
    log_message "Deploying ArgoCD bootstrap..."
    
    # Add Argo Helm repo
    helm repo add argo https://argoproj.github.io/argo-helm 2>&1 | tee -a "$HELM_LOG_FILE" || true
    helm repo update 2>&1 | tee -a "$HELM_LOG_FILE"
    
    # Check if ArgoCD already installed
    if helm list -n argocd | grep -q argocd; then
        log_message "ArgoCD already installed, upgrading..."
        helm upgrade argocd argo/argo-cd \
            --namespace argocd \
            --wait --timeout 5m 2>&1 | tee -a "$HELM_LOG_FILE" || {
            log_error "ArgoCD upgrade failed"
            handle_failure "$operation" 1 "argocd_upgrade"
        }
    else
        log_message "Installing ArgoCD..."
        helm install argocd argo/argo-cd \
            --namespace argocd \
            --create-namespace \
            --wait --timeout 5m 2>&1 | tee -a "$HELM_LOG_FILE" || {
            log_error "ArgoCD installation failed"
            handle_failure "$operation" 1 "argocd_install"
        }
    fi
    
    log_message "✓ ArgoCD deployed"
    
    # Apply root app (App of Apps)
    log_message "Deploying ArgoCD root application..."
    kubectl apply -f "$GITOPS_DIR/bootstrap/root-app.yaml" || {
        log_error "Failed to apply root app"
        handle_failure "$operation" 1 "root_app_apply"
    }
    
    log_message "✓ Root app deployed - ArgoCD will sync all applications"
    
    # Wait for initial sync
    log_message "Waiting for ArgoCD applications to sync..."
    sleep 10
    
    # Show application status
    kubectl get applications -n argocd
    
    log_message "✓ ArgoCD bootstrap complete"
}
```

**Why Not Automated**:
- User may want to review GitOps values first
- Requires stable GitOps repo (injection must run first)
- ArgoCD is critical infrastructure - manual verification safer
- May want custom ArgoCD configuration

---

### 4. **Preflight Check** (Partially Broken)

**Status**: ⚠️ **EXISTS BUT BROKEN**

**Current Issue**:
```bash
# preflight-check.sh references non-existent files:
DEPS_FILE="$WORKSPACE_ROOT/configs/project-dependencies.md"  # ← DOES NOT EXIST
CENTRAL_CONFIG_FILE="$PROJECT_ROOT/configs/central-config.yaml"  # ← DOES NOT EXIST
```

**What It Checks**:
- AWS CLI installed
- kubectl installed
- helm installed
- terraform installed
- jq installed
- SSH keys configured
- AWS credentials configured

**What Needs Fixing**:
```bash
# Remove dependency on external config files
# Hardcode checks like we did in config-loader.sh

REQUIRED_TOOLS=(
    "aws:AWS CLI:required"
    "kubectl:Kubernetes CLI:required"
    "helm:Helm:required"
    "terraform:Terraform:required"
    "jq:JSON processor:required"
    "git:Git:required"
)

OPTIONAL_TOOLS=(
    "yq:YAML processor:optional"
    "argocd:ArgoCD CLI:optional"
)
```

---

### 5. **DNS Verification** (Weather App Specific)

**Status**: ⚠️ **EXISTS BUT NOT APPLICABLE**

**Current Issue**:
```bash
# verify-dns.sh is specific to weather app architecture:
- Checks for ALBs created by Helm
- Verifies NS delegation
- Updates central-config.yaml with ALB DNS names

# Not needed for quiz app because:
- ALBs are created by ArgoCD (not directly by scripts)
- Route53 records are in terraform (not manual)
- No central-config.yaml to update
```

**What Quiz App Needs**:
```bash
# Simple verification after deployment:
verify_quiz_app_deployment() {
    log_message "Verifying Quiz App deployment..."
    
    # Check if ArgoCD deployed successfully
    kubectl get application quiz-app -n argocd
    
    # Check if quiz app pods are running
    kubectl get pods -n quiz-app
    
    # Get ALB DNS name
    ALB_DNS=$(kubectl get ingress quiz-app-ingress -n quiz-app \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    log_message "Quiz App ALB DNS: $ALB_DNS"
    log_message "Quiz App URL: https://quiz.weatherlabs.org"
    
    # Verify DNS resolution
    dig +short quiz.weatherlabs.org
}
```

---

## Summary of Missing Scripts

| Script | Status | Priority | Effort | Blocks Workflow |
|--------|--------|----------|--------|-----------------|
| **inject-argocd-values.sh** | ❌ **MISSING** | **CRITICAL** | 2-3 hours | ✅ **YES** |
| Git commit/push automation | ❌ Not implemented | Medium | 1 hour | ❌ No (can do manually) |
| ArgoCD bootstrap deploy | ❌ Not implemented | Medium | 1 hour | ❌ No (can do manually) |
| Preflight check fixes | ⚠️ Broken | Low | 1 hour | ❌ No (can skip) |
| DNS verification | ⚠️ Not applicable | Low | 30 min | ❌ No (not needed) |

---

## Current Script Execution Flow

```bash
# User runs:
./manage-project.sh --apply

# What happens:
1. ✅ Sources config-loader.sh (loads config)
2. ✅ Sources logging-helpers.sh (sets up logging)
3. ❌ run_preflight_check() - calls broken preflight-check.sh
4. ✅ apply_run_terraform() - runs terraform apply
5. ✅ apply_configure_prod_cluster() - configures kubectl
6. ❌ inject_terraform_values() - FAILS (function doesn't exist)
7. ✅ apply_log_summary() - shows summary
8. ❌ User must manually:
   - Update GitOps values with terraform outputs
   - Commit and push GitOps changes
   - Deploy ArgoCD with Helm
   - Apply root-app.yaml
```

---

## Recommended Implementation Priority

### Phase 1: Critical (Blocks Automation)
1. **Create inject-argocd-values.sh** (~2-3 hours)
   - Fetch terraform outputs
   - Update GitOps YAML files
   - Use sed (no yq dependency)

### Phase 2: High Value (Easy Automation)
2. **Add ArgoCD bootstrap deployment** (~1 hour)
   - Add to workflow.sh after injection
   - Helm install ArgoCD
   - Apply root-app.yaml

### Phase 3: Nice to Have
3. **Git commit/push automation** (~1 hour)
   - Optional feature
   - Requires git credentials
   - Can be enabled/disabled via flag

4. **Fix preflight-check.sh** (~1 hour)
   - Remove config file dependencies
   - Hardcode tool checks
   - Add fallback checks

5. **Remove/replace verify-dns.sh** (~30 min)
   - Not applicable to quiz app
   - Replace with simple deployment verification

---

## Implementation Approach

### Option 1: Minimal (Just Injection)
```bash
# Create only inject-argocd-values.sh
# User still does:
- Git commit/push manually
- ArgoCD deployment manually
```

### Option 2: Semi-Automated (Recommended)
```bash
# Create:
1. inject-argocd-values.sh
2. ArgoCD bootstrap deployment
# User still does:
- Git commit/push manually (review changes)
```

### Option 3: Full Automation
```bash
# Create all scripts
# Add flags for manual override:
./manage-project.sh --apply --auto-commit --auto-deploy-argocd
```

---

## Files That Need Creation/Fixing

### New Files to Create:
```
pipeline/iac/scripts/management/lib/operations/apply/
└── inject-argocd-values.sh          # ← NEW (CRITICAL)
```

### Files to Fix:
```
pipeline/iac/scripts/management/lib/bootstrap/
├── preflight-check.sh                # FIX (remove config deps)
└── verify-dns.sh                     # REMOVE or REPLACE
```

### Files to Update:
```
pipeline/iac/scripts/management/lib/operations/apply/
└── workflow.sh                       # ADD argocd deployment call
```

---

## Questions for Next Steps

1. **Do you want me to create inject-argocd-values.sh now?**
   - This is critical and blocks the workflow
   - Should I use sed or yq for YAML updates?

2. **Should I add ArgoCD bootstrap deployment to scripts?**
   - Makes it one-command deployment
   - Or prefer keeping it manual?

3. **Git automation - yes or no?**
   - Requires git credentials
   - Could add as optional flag: `--auto-commit`

4. **Preflight check - fix or remove?**
   - It checks useful stuff (aws cli, kubectl, etc.)
   - But currently broken due to config file deps

5. **verify-dns.sh - keep, fix, or remove?**
   - Not applicable to current architecture
   - Could replace with simple deployment verification

---

**Recommendation**: Start with **inject-argocd-values.sh** (critical) and **ArgoCD deployment automation** (high value). Keep git commit manual for now (safety).
