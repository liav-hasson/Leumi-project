#!/bin/bash
# Simple GitOps updater for ArgoCD repository

set -e

# Parameters passed explicitly from Jenkins
DOCKER_USERNAME="$1"
IMAGE_TAG="$2"
BUILD_NUMBER="$3"
ARGOCD_REPO_URL="$4"
GIT_USER_NAME="$5"
GIT_USER_EMAIL="$6"

# Validation
if [ -z "$DOCKER_USERNAME" ] || [ -z "$IMAGE_TAG" ] || [ -z "$ARGOCD_REPO_URL" ] || [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    echo "Usage: $0 <docker_username> <image_tag> <build_number> <argocd_repo_url> <git_user_name> <git_user_email>"
    echo "❌ Missing required parameters:"
    echo "   DOCKER_USERNAME: '$DOCKER_USERNAME'"
    echo "   IMAGE_TAG: '$IMAGE_TAG'"  
    echo "   BUILD_NUMBER: '$BUILD_NUMBER'"
    echo "   ARGOCD_REPO_URL: '$ARGOCD_REPO_URL'"
    echo "   GIT_USER_NAME: '$GIT_USER_NAME'"
    echo "   GIT_USER_EMAIL: '$GIT_USER_EMAIL'"
    exit 1
fi

echo "🚀 Updating GitOps repository..."
echo "   Image: ${DOCKER_USERNAME}/weather-app:${IMAGE_TAG}"

# Create temp workspace
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone argocd-repo (shallow + sparse for efficiency)
echo "--------- Cloning repository ---------"
echo "   Repository: $ARGOCD_REPO_URL"
echo "   Git user: $GIT_USER_NAME <$GIT_USER_EMAIL>"
git clone --depth=1 --filter=blob:none --sparse "$ARGOCD_REPO_URL" .
git sparse-checkout set weather-deployment
git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

# Update values.yaml
echo "--------- Updating Helm values ---------"
cd weather-deployment

sed -i "s|repository: .*|repository: ${DOCKER_USERNAME}/weather-app|g" values.yaml
sed -i "s|tag: \".*\"|tag: \"${IMAGE_TAG}\"|g" values.yaml
sed -i "s|appVersion: \".*\"|appVersion: \"${IMAGE_TAG}\"|g" Chart.yaml

# Commit and push
echo "--------- Committing changes ---------"
git add values.yaml Chart.yaml
git commit -m "🚀 Deploy weather-app:${IMAGE_TAG}

- Updated from Jenkins build #${BUILD_NUMBER:-unknown}
- Image: ${DOCKER_USERNAME}/weather-app:${IMAGE_TAG}"

git push origin main

# Cleanup
rm -rf "$TEMP_DIR"

echo "GitOps update complete!"