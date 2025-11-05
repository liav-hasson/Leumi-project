#!/bin/bash

# to fix - remove depricated scripts, wrong resources

set -euo pipefail

# Utilities Script for Kubespray Cluster Management
# This script provides various utility functions for cluster access and management

# Dynamic path detection - find project root from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

KUBECONFIG_DIR="$PROJECT_ROOT/infrastructure-repo/kubeconfig"

# Load shared configuration and logging
source "$SCRIPT_DIR/lib/helpers/config-loader.sh"
source "$SCRIPT_DIR/lib/helpers/logging-helpers.sh"

# Script paths
SSM_TUNNEL_SCRIPT="$SSM_TUNNELS_SCRIPT"

# Static hostnames (from Helm values) - used for display only
# These match the values hardcoded in argocd-repo/*/values*.yaml
readonly WEATHER_PROD_HOST="${WEATHER_PROD_HOST:-weatherlabs.org}"
readonly WEATHER_DEV_HOST="${WEATHER_DEV_HOST:-dev.weatherlabs.org}"
readonly DEV_GITLAB_PUBLIC_HOST="${DEV_GITLAB_PUBLIC_HOST:-gitlab.weatherlabs.org}"
readonly DEV_JENKINS_PUBLIC_HOST="${DEV_JENKINS_PUBLIC_HOST:-jenkins.weatherlabs.org}"
readonly DEV_GITLAB_INTERNAL_HOST="${DEV_GITLAB_INTERNAL_HOST:-gitlab.default.svc.cluster.local}"
readonly DEV_JENKINS_INTERNAL_HOST="${DEV_JENKINS_INTERNAL_HOST:-jenkins.default.svc.cluster.local}"

echo_line() { printf "%s\n" "$*"; }


get_prod_access_info() {
    # Get production access info (EXTERNAL_IP, ARGOCD_PASSWORD)
    # Returns key=value lines: EXTERNAL_IP, ARGOCD_PASSWORD
    # 
    # Note: With GitOps migration, we now use static DNS hostnames.
    # The ALB is managed by AWS Load Balancer Controller via Ingress resources.
    local external_ip="$WEATHER_PROD_HOST"
    local password=""
    
    # Try to get ArgoCD admin password from the cluster (if available)
    # This requires kubectl access to the prod cluster
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        password=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    fi

    # Print key=value lines (callers parse these)
    echo "EXTERNAL_IP=$external_ip"
    echo "ARGOCD_PASSWORD=$password"
    return 0
}

# Flag: --access | -a
# Display cluster access information
show_cluster_access() {
    log_message "Fetching cluster access information..."
    
    local dev_admin_kubeconfig="$HOME/.kube/dev-cluster-admin.conf"
    local jenkins_kubeconfig="$KUBECONFIG_DIR/jenkins-kubeconfig.yaml"
    
    echo_line
    echo_line "Cluster Access Information"
    echo_line "--------------------------"
    echo_line "Dev cluster:    kubectl config use-context kubernetes-admin@cluster.local"
    echo_line "                (requires SSM tunnel to port 6443)"
    echo_line "Prod cluster:   kubectl config use-context $EKS_CLUSTER_NAME"
    echo_line
    echo_line "Note: Dev admin kubeconfig at: $dev_admin_kubeconfig"
    echo_line "      Jenkins SA kubeconfig at: $jenkins_kubeconfig (internal use only)"
    echo_line
    echo_line "Dev Cluster (ALB):"
    if [[ -n "$DEV_GITLAB_PUBLIC_HOST" ]]; then
        echo_line "  GitLab UI:   http://$DEV_GITLAB_PUBLIC_HOST"
    fi
    if [[ -n "$DEV_JENKINS_PUBLIC_HOST" ]]; then
        echo_line "  Jenkins UI:  http://$DEV_JENKINS_PUBLIC_HOST"
    fi
    if [[ -n "$WEATHER_DEV_HOST" ]]; then
        echo_line "  Weather App: http://$WEATHER_DEV_HOST"
    fi
    if [[ -n "$DEV_GITLAB_INTERNAL_HOST" || -n "$DEV_JENKINS_INTERNAL_HOST" ]]; then
        echo_line
        echo_line "  Internal DNS (within VPC):"
        [[ -n "$DEV_GITLAB_INTERNAL_HOST" ]] && echo_line "    - GitLab: $DEV_GITLAB_INTERNAL_HOST"
        [[ -n "$DEV_JENKINS_INTERNAL_HOST" ]] && echo_line "    - Jenkins: $DEV_JENKINS_INTERNAL_HOST"
    fi
    echo ""
    
    # Get prod access info (returns EXTERNAL_IP, ARGOCD_PASSWORD)
    echo_line "Prod Cluster (EKS):"
    local prod_info
    if prod_info=$(get_prod_access_info 2>/dev/null); then
        local external_ip=$(echo "$prod_info" | grep "EXTERNAL_IP=" | cut -d'=' -f2)
        local password=$(echo "$prod_info" | grep "ARGOCD_PASSWORD=" | cut -d'=' -f2)
        
        if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
            echo_line "  ArgoCD UI:   http://$external_ip/argo"
            echo_line "  ArgoCD User: admin"
            if [[ -n "$password" && "$password" != "null" ]]; then
                echo_line "  ArgoCD Pass: $password"
            fi
            echo_line
            echo_line "  WeatherApp: http://$external_ip/"
        else
            echo_line "  Status: Prod ingress not ready"
            echo_line "  * ArgoCD installs automatically with cluster"
        fi
    else
        echo_line "  Status: No ingress found"
        echo_line "  * ArgoCD installs automatically with cluster"
    fi
    echo ""
}

# Flag: --open | -o
# Open web UIs in browser (optional)
# Triggered by: project-utils --open  (or -o)
open_web_uis() {
    log_message "Getting web UI URLs..."
    
    echo_line
    echo_line "Web UI Access"
    echo_line "-------------"
    echo_line "Dev cluster uses ALB + ExternalName services; URLs appear after ALB is ready."
    echo_line

    local gitlab_url=""
    local jenkins_url=""
    local dev_weather_url=""
    if [[ -n "$DEV_GITLAB_PUBLIC_HOST" ]]; then
        gitlab_url="http://$DEV_GITLAB_PUBLIC_HOST"
        echo_line "GitLab UI: $gitlab_url"
    fi
    if [[ -n "$DEV_JENKINS_PUBLIC_HOST" ]]; then
        jenkins_url="http://$DEV_JENKINS_PUBLIC_HOST"
        echo_line "Jenkins UI: $jenkins_url"
    fi
    if [[ -n "$WEATHER_DEV_HOST" ]]; then
        dev_weather_url="http://$WEATHER_DEV_HOST"
        echo_line "Weather App: $dev_weather_url"
    fi
    
    # Get prod access info (returns EXTERNAL_IP, ARGOCD_PASSWORD)
    local argocd_url=""
    local weather_url=""
    if prod_info=$(get_prod_access_info 2>/dev/null); then
        local external_ip=$(echo "$prod_info" | grep "EXTERNAL_IP=" | cut -d'=' -f2)
        
        local prod_url=""
        if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
            prod_url="$external_ip"
        fi
        
        if [[ -n "$prod_url" ]]; then
            argocd_url="http://$prod_url/argo"
            weather_url="http://$prod_url/"
            echo_line "ArgoCD UI: $argocd_url"
            echo_line "Weather App: $weather_url"
        fi
    fi
    echo ""
    
    # Check if we're in a desktop environment and open URLs
    if command -v xdg-open >/dev/null 2>&1; then
        echo_line "Opening URLs in browser..."
        [[ -n "$jenkins_url" ]] && xdg-open "$jenkins_url" 2>/dev/null &
        [[ -n "$gitlab_url" ]] && xdg-open "$gitlab_url" 2>/dev/null &
        [[ -n "$dev_weather_url" ]] && xdg-open "$dev_weather_url" 2>/dev/null &
        if [[ -n "$argocd_url" ]]; then
            xdg-open "$argocd_url" 2>/dev/null &
            xdg-open "$weather_url" 2>/dev/null &
        fi
    elif command -v open >/dev/null 2>&1; then
        echo_line "Opening URLs in browser..."
        [[ -n "$jenkins_url" ]] && open "$jenkins_url" 2>/dev/null &
        [[ -n "$gitlab_url" ]] && open "$gitlab_url" 2>/dev/null &
        [[ -n "$dev_weather_url" ]] && open "$dev_weather_url" 2>/dev/null &
        if [[ -n "$argocd_url" ]]; then
            open "$argocd_url" 2>/dev/null &
            open "$weather_url" 2>/dev/null &
        fi
    else
        echo_line "No browser command found. Copy the URLs above manually."
    fi
}

# Flag: --gitlab | -g
# Show SSM tunnels status (GitLab SSH and Kubernetes API)
# Triggered by: project-utils --gitlab  (or -g)
show_gitlab_tunnel_status() {
    log_message "Checking SSM tunnels status..."
    
    if [ ! -f "$SSM_TUNNEL_SCRIPT" ]; then
        error "SSM tunnel script not found at $SSM_TUNNEL_SCRIPT"
        return 1
    fi
    
    echo_line
    echo_line "SSM Tunnels Status"
    echo_line "------------------"
    echo_line
    
    # Show current status
    local status_output
    status_output=$("$SSM_TUNNEL_SCRIPT" status 2>&1)
    local status_exit_code=$?
    
    echo_line "$status_output"
    echo_line
    
    # Show management commands
    echo_line "Management Commands:"
    echo_line "  ssm-tunnels start|stop|restart|status [gitlab|kubernetes|all]"
    echo_line
}

# Flag: --argocd | -r
# Manage ArgoCD installation and status
# Triggered by: project-utils --argocd  (or -r)
manage_argocd() {
    log_message "Managing ArgoCD installation..."

    echo_line
    echo_line "ArgoCD Management"
    echo_line "-----------------"
    echo_line

    # Check if ArgoCD is already installed
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo_line "ArgoCD namespace exists"

        # Check ArgoCD pods status
        echo_line "Checking ArgoCD pods status..."
        kubectl get pods -n argocd --no-headers 2>/dev/null | while read line; do
            pod_name=$(echo $line | awk '{print $1}')
            pod_status=$(echo $line | awk '{print $3}')
            if [ "$pod_status" = "Running" ]; then
                echo_line "  $pod_name: $pod_status"
            else
                echo_line "  $pod_name: $pod_status"
            fi
        done

        # Show access information using kubectl (no external scripts)
        echo_line
        echo_line "ArgoCD Access (public): http://argocd.weatherlabs.org"
        local password
        password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true)
        echo_line "  Username: admin"
        [[ -n "$password" ]] && echo_line "  Password: $password" || echo_line "  Password not available"

    else
        echo_line "ArgoCD not installed (will be installed by bootstrap-dev)"
    fi

    # Show management commands
    echo_line
    echo_line "ArgoCD CLI: argocd login <server> --username admin --password <password>"
    echo_line
}

# NLB cross-zone configuration removed - ALB handles cross-zone automatically

# Flag: --help | -h
# Show help
show_help() {
    echo_line
    echo_line "Project Utilities - Cluster Management"
    echo_line "-------------------------------------"
    echo_line "Usage: project-utils [OPTIONS]"
    echo_line
    echo_line "Options:"
    echo_line "  --access,   -a       Show access information (dev + prod)"
    echo_line "  --argocd,   -r       Show ArgoCD status"
    echo_line "  --gitlab,   -g       Show SSM tunnels status (GitLab + Kubernetes)"
    echo_line "  --open,     -o       Open web UIs in browser"
    echo_line "  --help,     -h       Show this help"
    echo_line
}

# Main function
main() {
    case "${1:-help}" in
        "--access"|"-a")
            show_cluster_access
            ;;
        "--argocd"|"-r")
            manage_argocd
            ;;
        "--gitlab"|"-g")
            show_gitlab_tunnel_status
            ;;
        "--open"|"-o")
            open_web_uis
            ;;
        "--help"|"-h"|"help")
            show_help
            ;;
        *)
            echo_line "Unknown option: ${1:-}"
            echo_line "Use --help or -h to see available options"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
