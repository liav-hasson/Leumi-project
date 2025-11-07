# Core Project Scrips  

- the purpose of the scripts is to provide utilities, and make the workflow easy.
  
## How To Use

### Add add the scripts to your .bashrc file

```bash
# Go to the script directory
cd ~/github/Leumi-project/quiz-app/iac/scripts/management

# Get absolute path
SCRIPTS_DIR="$(pwd)"

# Append to ~/.bashrc
{
  echo ""
  echo "# === Leumi Project Management Scripts ==="
  echo "alias manage-project='bash \"$SCRIPTS_DIR/manage-project.sh\"'"
  echo "alias monitor-deployment='bash \"$SCRIPTS_DIR/monitor-deployment.sh\"'"
  echo "alias project-utils='bash \"$SCRIPTS_DIR/project-utils.sh\"'"
  echo "# ========================================"
} >> ~/.bashrc

# Reload bashrc immediately
source ~/.bashrc
```

## 1. manage-project

```bash
$ manage-project -h
Usage: manage-project {apply|destroy|validate}


Commands:
  --apply,    -a     - Deploy infrastructure and configure GitOps
  --destroy,  -d     - Tear down all infrastructure
  --validate, -v     - Validate Helm chart structure and configuration
```

## 2. monitor-deploy

```bash
$ monitor-deploy -h

🖥️  WeatherLabs Deployment Monitor
=================================

Usage: monitor-deployment.sh [options]

Options:
  -h, --help          Show this help and exit
  -s, --status        Summarise log files for the current bundle
  -t, --tail <N>      Display the last N lines from each log (default 20)
  -f, --filter        Follow logs in real time and highlight key events only
  -c, --clear         Remove all log files for the current bundle

Notes:
  • Logs are stored under /tmp/quiz-app-deploy
  • Use --filter during deployments for a concise view
```

## 3. project-utils

```bash
$ project-utils -h

╔════════════════════════════════════════════════════════════╗
║        Quiz App DevOps - Project Utilities                 ║
╚════════════════════════════════════════════════════════════╝

Usage: project-utils [OPTIONS]

Options:
  --access,   -a       Show access information (cluster + apps)
  --argocd,   -r       Show ArgoCD status
  --open,     -o       Open web UIs in browser
  --help,     -h       Show this help

```
