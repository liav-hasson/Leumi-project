#!/bin/bash

### INFRASTRUCTURE PROVISIONING + CONFIGURATION SCRIPT ###
# 
## Purpose: Deploy and manage weatherLabs infrastructure
## Function: Runs terraform, then configures resources using Helm/bash/ansible
## 
## This is the main entry point that sources modular libraries and operations


### Core Path Variables ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source Library Modules
# Load configuration from central-config.yaml (use PROJECT_ROOT to avoid ambiguous SCRIPT_DIR when sourced)
source "$PROJECT_ROOT/infrastructure-repo/scripts/management/lib/helpers/config-loader.sh"

# Load helper functions (absolute paths from project root)
source "$PROJECT_ROOT/infrastructure-repo/scripts/management/lib/helpers/logging-helpers.sh"
source "$PROJECT_ROOT/infrastructure-repo/scripts/management/lib/helpers/kube-helpers.sh"
source "$PROJECT_ROOT/infrastructure-repo/scripts/management/lib/helpers/git-helpers.sh"
source "$PROJECT_ROOT/infrastructure-repo/scripts/management/lib/helpers/notification-helpers.sh"
source "$PROJECT_ROOT/infrastructure-repo/scripts/management/lib/helpers/validation-helpers.sh"
# Note: argocd-helpers.sh removed - ArgoCD now manages deployments via GitOps

### Main Execution ###
case "${1:-help}" in
    "--apply"|"-a")
        echo "Starting apply; logs: $LOG_DIR (use monitor-deployment.sh --filter)"
        # Load and execute apply operation
        source "$PROJECT_ROOT/infrastructure-repo/scripts/management/operations/apply.sh"
        terraform-apply
        ;;
    "--destroy"|"-d")
        echo "Starting destroy; logs: $LOG_DIR (use monitor-deployment.sh --filter)"
        # Load and execute destroy operation
        source "$PROJECT_ROOT/infrastructure-repo/scripts/management/operations/destroy.sh"
        terraform-destroy
        ;;
    "--validate"|"-v")
        # Load and execute validate operation
        source "$PROJECT_ROOT/infrastructure-repo/scripts/management/operations/validate.sh"
        validate-charts
        ;;
    *)
        echo "Usage: manage-project {apply|destroy|validate}"
        echo ""
        echo "Commands:"
        echo "  --apply,    -a     - Deploy infrastructure and Helm charts"
        echo "  --destroy,  -d     - Tear down all infrastructure"
        echo "  --validate, -v     - Validate Helm chart structure and configuration"
        echo ""
        echo "Scripts Structure:"
        tree -d /home/liav/gitlab/weatherLabs/infrastructure-repo/scripts
        exit 1
        ;;
esac
