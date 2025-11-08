# Jenkins GitHub Migration - What Changed

## Jenkinsfile Changes

**Updated from GitLab to GitHub:**
- Changed credentials: `GIT_CREDENTIALS` → `GITHUB_CREDENTIALS`
- Changed API token: `GITLAB_API_TOKEN` → `GITHUB_TOKEN`
- Updated repository URL to: `https://github.com/liav-hasson/Leumi-project.git`
- Changed GitHub API call in post section (commit status updates)
- Fixed image name: `weather-app` → `quiz-app`

## GitOps Script Changes

**File:** `quiz-app/src/scripts/update-gitops.sh`
- Updated to work with same repo (not separate ArgoCD repo)
- Changed path to: `quiz-app/gitops/quiz-app/`
- Fixed image name to `quiz-app`

---

## Required Jenkins Credentials

### NEW - Add These in Jenkins:

1. **`github-credentials`** (Username with password)
   - Username: `liav-hasson`
   - Password: [GitHub Personal Access Token]
   - Purpose: Clone/push to GitHub repo

2. **`github-token`** (Secret text)
   - Secret: [Same GitHub Personal Access Token]
   - Purpose: GitHub API calls for commit status

3. **`jenkins-eks-token`** (Secret text)
   - Secret: [EKS service account token]
   - Get with: `kubectl get secret jenkins-token -n jenkins -o jsonpath='{.data.token}' | base64 -d`
   - Purpose: Jenkins authenticate with EKS


## Other Required Setup

### 1. GitHub Personal Access Token
- Go to: GitHub → Settings → Developer settings → Personal access tokens
- Scopes needed: `repo`, `admin:repo_hook`
- Use this token for both `github-credentials` and `github-token`

### put the webhook secret in jenkins credentials:
Add credential: Secret text
ID: github-webhook-secret
Secret: 1f185aa8e445b225b526d78f23749ced9cdf6539221f828bba1dd427e4da19d4


### 4. Jenkins GitHub Plugin
- Manage Jenkins → Configure System → GitHub
- Add GitHub Server with `github-token` credential
- API URL: `https://api.github.com`

### 5. Jenkins Kubernetes Cloud
- Add EKS cluster with `jenkins-eks-token` credential
- API Server: Get from `kubectl config view --minify`


# done:

### 2. GitHub Webhook
- URL: `https://jenkins.weatherlabs.org/github-webhook/`
- Content type: `application/json`
- Events: Push events, Pull requests