# Missing Components Analysis - Quiz App Infrastructure

## Executive Summary

After reviewing the scripts and GitOps structure, there are **2 major gaps** for full automation:

1. **Scripts Gap:** Missing injection script for automated ArgoCD value updates
2. **GitOps Gap:** Missing platform/infrastructure chart for Jenkins agent resources on EKS

---

## Part 1: Script Automation Gaps

### What Scripts Currently Do ✅
- ✅ Terraform init and apply (provisions all AWS infrastructure)
- ✅ Configure kubectl access to EKS cluster
- ✅ Log terraform outputs
- ✅ Display access information

### What's Missing for Full Automation ❌

#### 1. **Injection Script** (CRITICAL - High Priority)
**Purpose:** Automatically update ArgoCD/GitOps values with terraform outputs

**Current Process (Manual):**
```bash
# User must manually:
1. Get terraform outputs (ALB ARNs, cluster info, etc.)
2. Edit pipeline/gitops/*/values.yaml files
3. Update image registry URLs
4. Update ingress annotations
5. Git commit and push
```

**Should Be Automated:**
```bash
#!/bin/bash
# inject-argocd-values.sh

# Fetch terraform outputs
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
ALB_CONTROLLER_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)
EXTERNAL_SECRETS_ROLE_ARN=$(terraform output -raw external_secrets_role_arn)
AWS_REGION=$(terraform output -raw region)
VPC_ID=$(terraform output -raw vpc_id)
CERTIFICATE_ARN=$(terraform output -raw acm_certificate_arn)

# Update bootstrap values
yq eval -i ".eksCluster.name = \"$EKS_CLUSTER_NAME\"" pipeline/gitops/bootstrap/values.yaml
yq eval -i ".aws.region = \"$AWS_REGION\"" pipeline/gitops/bootstrap/values.yaml

# Update ArgoCD ingress with certificate
yq eval -i ".argocd.ingress.annotations[\"alb.ingress.kubernetes.io/certificate-arn\"] = \"$CERTIFICATE_ARN\"" pipeline/gitops/bootstrap/values.yaml

# Update quiz-app ingress
yq eval -i ".ingress.annotations[\"alb.ingress.kubernetes.io/certificate-arn\"] = \"$CERTIFICATE_ARN\"" pipeline/gitops/quiz-app/values.yaml

echo "✓ ArgoCD values updated from terraform outputs"
echo "Next: git commit and push changes"
```

**Files to Update:**
- `pipeline/gitops/bootstrap/values.yaml` (if it exists)
- `pipeline/gitops/quiz-app/values.yaml`
- `pipeline/gitops/applications/*.yaml`

**Why It's Missing:**
- Originally part of weather app but not ported to quiz app
- Requires `yq` tool (YAML processor)
- Low priority since it's a one-time operation after terraform apply

---

#### 2. **ArgoCD Bootstrap Deployment** (Medium Priority)
**Purpose:** Automatically deploy ArgoCD using Helm after terraform

**Current Process (Manual):**
```bash
# User must manually run:
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f pipeline/gitops/bootstrap/values.yaml
```

**Could Be Automated in Scripts:**
```bash
# In terraform.sh or separate bootstrap.sh
apply_deploy_argocd_bootstrap() {
    echo "Deploying ArgoCD bootstrap..."
    
    # Add Argo Helm repo
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Install ArgoCD
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        -f "$GITOPS_DIR/bootstrap/values.yaml" \
        --wait --timeout 5m
    
    # Deploy root app (App of Apps)
    kubectl apply -f "$GITOPS_DIR/bootstrap/root-app.yaml"
    
    echo "✓ ArgoCD deployed and syncing applications"
}
```

**Why It's Not Automated:**
- Requires stable GitOps values (needs injection script first)
- User might want to review values before deploying
- ArgoCD is critical infrastructure - manual verification is safer

---

#### 3. **Git Commit/Push Automation** (Low Priority)
**Purpose:** Automatically commit and push GitOps changes

**Current Process (Manual):**
```bash
cd pipeline/gitops
git add .
git commit -m "Update values from terraform outputs"
git push
```

**Could Be Automated:**
```bash
apply_push_gitops_changes() {
    cd "$GITOPS_DIR"
    
    if [[ -n $(git status --porcelain) ]]; then
        git add values.yaml applications/*.yaml
        git commit -m "chore: Update ArgoCD values from terraform outputs [automated]"
        git push origin main
        echo "✓ GitOps changes pushed to GitHub"
    else
        echo "No GitOps changes to commit"
    fi
}
```

**Why It's Not Automated:**
- Security: automated git pushes require credentials/SSH keys
- User might want to review changes before committing
- Could break if git credentials not configured

---

## Part 2: Missing GitOps Resources for Jenkins Agents on EKS

### Current GitOps Structure
```
pipeline/gitops/
├── applications/
│   ├── aws-load-balancer-controller.yaml
│   ├── external-secrets.yaml
│   └── quiz-app.yaml                      # Quiz application
├── bootstrap/
│   └── root-app.yaml                      # ArgoCD App of Apps
└── quiz-app/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/                          # Quiz app K8s resources
```

### What's Missing: Platform/Infrastructure Chart ❌

Since **Jenkins agents run on EKS** (not on Jenkins EC2), the EKS cluster needs:

#### Required Resources for Jenkins Agents:

1. **Jenkins Namespace**
   - Privileged namespace for builds
   - Pod security policies allowing privileged containers

2. **Jenkins ServiceAccount**
   - Service account for Jenkins agents
   - ClusterRoleBinding with cluster-admin permissions
   - Static token for Jenkins controller to authenticate

3. **BuildKit DaemonSet**
   - Docker image builds without Docker daemon
   - Runs privileged containers on each node
   - Mounted at `tcp://buildkitd:1234`

4. **BuildKit Service**
   - ClusterIP service exposing BuildKit daemon
   - Jenkins agents connect to `buildkitd.jenkins.svc.cluster.local:1234`

5. **Docker Registry Secret** (Optional)
   - Credentials for private Docker registry
   - Used by BuildKit for pushing images
   - Sourced from AWS SSM via External Secrets

6. **External Secrets Resources**
   - SecretStore for Jenkins namespace
   - ExternalSecret for Docker credentials

---

### Recommended GitOps Structure

```
pipeline/gitops/
├── applications/
│   ├── aws-load-balancer-controller.yaml
│   ├── external-secrets.yaml
│   ├── jenkins-platform.yaml              # ← NEW: Platform resources
│   └── quiz-app.yaml
├── bootstrap/
│   └── root-app.yaml
├── jenkins-platform/                       # ← NEW CHART
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── namespace.yaml                  # jenkins namespace with privileged PSP
│       ├── serviceaccount.yaml             # jenkins service account
│       ├── clusterrolebinding.yaml         # cluster-admin binding
│       ├── sa-token-secret.yaml            # static token for Jenkins
│       ├── buildkit-daemonset.yaml         # BuildKit daemon on nodes
│       ├── buildkit-service.yaml           # BuildKit service
│       ├── secretstore.yaml                # External Secrets store
│       └── docker-credentials-externalsecret.yaml  # Docker registry secret
└── quiz-app/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

---

### Files to Create

#### 1. Application Definition: `applications/jenkins-platform.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jenkins-platform
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/liav/Leumi-project.git
    targetRevision: main
    path: pipeline/gitops/jenkins-platform
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: jenkins
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### 2. Chart Definition: `jenkins-platform/Chart.yaml`

```yaml
apiVersion: v2
name: jenkins-platform
description: Jenkins Agent Platform Resources for EKS
type: application
version: 1.0.0
appVersion: "1.0"
```

#### 3. Values: `jenkins-platform/values.yaml`

```yaml
# Jenkins Platform Configuration
# Resources for Jenkins agents running on EKS

jenkins:
  enabled: true
  namespace: jenkins
  serviceAccountName: jenkins
  clusterRoleBindingName: jenkins-cluster-admin
  
  # Static token for Jenkins controller to authenticate
  # Generated token will be: jenkins-<random>
  serviceAccountToken:
    enabled: true
    secretName: jenkins-token

buildkit:
  enabled: true
  namespace: jenkins
  image: moby/buildkit:v0.12.0
  port: 1234
  
  # Docker config secret for private registry authentication
  dockerConfigSecretName: docker-config

# External Secrets Operator integration
externalSecrets:
  enabled: true
  namespace: jenkins
  awsRegion: eu-north-1
  
  # SecretStore configuration
  secretStore:
    name: aws-parameter-store
    # Uses IRSA - External Secrets Operator service account has IAM role
  
  # Docker registry credentials from SSM
  dockerRegistry:
    enabled: true
    secretName: docker-config
    ssmParameterPath: /quiz-app/docker-registry-config
```

#### 4. Templates (see detailed YAML below)

---

### Template Files Content

#### `jenkins-platform/templates/namespace.yaml`

```yaml
{{- if .Values.jenkins.enabled }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.jenkins.namespace }}
  labels:
    name: {{ .Values.jenkins.namespace }}
    # Allow privileged containers for builds
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: privileged
    pod-security.kubernetes.io/audit: privileged
{{- end }}
```

#### `jenkins-platform/templates/serviceaccount.yaml`

```yaml
{{- if .Values.jenkins.enabled }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.jenkins.serviceAccountName }}
  namespace: {{ .Values.jenkins.namespace }}
{{- end }}
```

#### `jenkins-platform/templates/clusterrolebinding.yaml`

```yaml
{{- if .Values.jenkins.enabled }}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .Values.jenkins.clusterRoleBindingName }}
subjects:
- kind: ServiceAccount
  name: {{ .Values.jenkins.serviceAccountName }}
  namespace: {{ .Values.jenkins.namespace }}
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
{{- end }}
```

#### `jenkins-platform/templates/sa-token-secret.yaml`

```yaml
{{- if and .Values.jenkins.enabled .Values.jenkins.serviceAccountToken.enabled }}
# Static token secret for Jenkins controller to authenticate with EKS
# Jenkins controller (on EC2) uses this token to create pods
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Values.jenkins.serviceAccountToken.secretName }}
  namespace: {{ .Values.jenkins.namespace }}
  annotations:
    kubernetes.io/service-account.name: {{ .Values.jenkins.serviceAccountName }}
type: kubernetes.io/service-account-token
{{- end }}
```

#### `jenkins-platform/templates/buildkit-daemonset.yaml`

```yaml
{{- if and .Values.jenkins.enabled .Values.buildkit.enabled }}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: buildkit-daemon
  namespace: {{ .Values.buildkit.namespace }}
  labels:
    app: buildkit-daemon
spec:
  selector:
    matchLabels:
      app: buildkit-daemon
  template:
    metadata:
      labels:
        app: buildkit-daemon
    spec:
      containers:
      - name: buildkitd
        image: {{ .Values.buildkit.image }}
        args:
        - --addr
        - tcp://0.0.0.0:{{ .Values.buildkit.port }}
        - --root
        - /var/lib/buildkit
        ports:
        - containerPort: {{ .Values.buildkit.port }}
          name: buildkit
          protocol: TCP
        securityContext:
          privileged: true
        volumeMounts:
        - name: buildkit-cache
          mountPath: /var/lib/buildkit
        {{- if .Values.buildkit.dockerConfigSecretName }}
        - name: docker-config
          mountPath: /root/.docker
          readOnly: true
        {{- end }}
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 2000m
            memory: 4Gi
      volumes:
      - name: buildkit-cache
        hostPath:
          path: /var/lib/buildkit
          type: DirectoryOrCreate
      {{- if .Values.buildkit.dockerConfigSecretName }}
      - name: docker-config
        secret:
          secretName: {{ .Values.buildkit.dockerConfigSecretName }}
          items:
          - key: config.json
            path: config.json
      {{- end }}
      tolerations:
      - effect: NoSchedule
        operator: Exists
{{- end }}
```

#### `jenkins-platform/templates/buildkit-service.yaml`

```yaml
{{- if and .Values.jenkins.enabled .Values.buildkit.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: buildkitd
  namespace: {{ .Values.buildkit.namespace }}
  labels:
    app: buildkit-daemon
spec:
  selector:
    app: buildkit-daemon
  ports:
  - name: tcp
    port: {{ .Values.buildkit.port }}
    targetPort: {{ .Values.buildkit.port }}
    protocol: TCP
  type: ClusterIP
{{- end }}
```

#### `jenkins-platform/templates/secretstore.yaml`

```yaml
{{- if and .Values.jenkins.enabled .Values.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: {{ .Values.externalSecrets.secretStore.name }}
  namespace: {{ .Values.externalSecrets.namespace }}
spec:
  provider:
    aws:
      service: ParameterStore
      region: {{ .Values.externalSecrets.awsRegion }}
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
{{- end }}
```

#### `jenkins-platform/templates/docker-credentials-externalsecret.yaml`

```yaml
{{- if and .Values.jenkins.enabled .Values.externalSecrets.enabled .Values.externalSecrets.dockerRegistry.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: docker-registry-credentials
  namespace: {{ .Values.externalSecrets.namespace }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStore.name }}
    kind: SecretStore
  target:
    name: {{ .Values.externalSecrets.dockerRegistry.secretName }}
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        config.json: "{{ `{{ .dockerConfig | toString }}` }}"
  data:
  - secretKey: dockerConfig
    remoteRef:
      key: {{ .Values.externalSecrets.dockerRegistry.ssmParameterPath }}
{{- end }}
```

---

## Part 3: Summary of Missing Components

### Script Gaps (Automation)

| Component | Status | Priority | Effort | Impact |
|-----------|--------|----------|--------|--------|
| Injection script | ❌ Missing | High | 2-3 hours | Automates value updates |
| ArgoCD bootstrap deploy | ❌ Missing | Medium | 1 hour | One command deployment |
| Git commit/push | ❌ Missing | Low | 30 min | Removes manual step |

### GitOps Gaps (Jenkins Agent Resources)

| Component | Status | Priority | Effort | Impact |
|-----------|--------|----------|--------|--------|
| jenkins-platform chart | ❌ Missing | **CRITICAL** | 3-4 hours | **Jenkins can't run agents without this** |
| Application definition | ❌ Missing | **CRITICAL** | 15 min | Deploys platform chart |
| BuildKit DaemonSet | ❌ Missing | **CRITICAL** | Included above | Docker builds fail without it |
| Jenkins namespace/RBAC | ❌ Missing | **CRITICAL** | Included above | Agents can't deploy without permissions |

---

## Part 4: Recommended Implementation Order

### Phase 1: Critical GitOps (REQUIRED for Jenkins to work)
1. ✅ Create `jenkins-platform` chart with all templates (~3-4 hours)
2. ✅ Create `applications/jenkins-platform.yaml` (~15 min)
3. ✅ Update `bootstrap/root-app.yaml` to include jenkins-platform app (~5 min)
4. ✅ Test deployment on EKS cluster

**Why Critical:** Without these, Jenkins agents cannot:
- Authenticate to EKS cluster (no service account)
- Create pods (no RBAC)
- Build Docker images (no BuildKit)
- Push images (no registry credentials)

### Phase 2: Script Automation (Nice to Have)
1. ✅ Create injection script (~2 hours)
2. ✅ Add ArgoCD bootstrap deployment to scripts (~1 hour)
3. ✅ Add git automation (optional) (~30 min)

**Why Lower Priority:** These are one-time manual steps that work fine

---

## Part 5: Quick Start - What to Do Next

### Option A: Manual Deployment (Fastest - 30 minutes)
```bash
# 1. Create jenkins-platform chart manually
mkdir -p pipeline/gitops/jenkins-platform/templates
# Copy templates from this document

# 2. Apply to cluster
kubectl apply -f pipeline/gitops/applications/jenkins-platform.yaml

# 3. Wait for sync
kubectl get application jenkins-platform -n argocd
```

### Option B: Full GitOps (Recommended - 4 hours)
```bash
# I can create all the files for you with proper structure
# Then you deploy ArgoCD which syncs everything automatically
```

---

## Questions for User

1. **Do you want me to create the jenkins-platform chart now?**
   - This is CRITICAL for Jenkins agents to work on EKS

2. **Docker Registry:** Where are you pushing images?
   - Docker Hub (public)?
   - AWS ECR?
   - Private registry?
   - This affects the docker-config secret

3. **SSM Parameter:** Do you have `/quiz-app/docker-registry-config` in SSM?
   - Or should I use a different path?
   - Or disable this feature if not using private registry?

4. **Script automation:** Do you want the injection script?
   - Or are you comfortable doing manual updates?

---

**Bottom Line:** The jenkins-platform chart is CRITICAL and missing. Without it, Jenkins cannot run build agents on your EKS cluster. Everything else is "nice to have" automation.
