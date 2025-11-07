# show visual examples of the scripts usage.

liav@liav-laptop:~/github/Leumi-project$ manage-project -h
Usage: manage-project {apply|destroy|validate}

Commands:
  --apply,    -a     - Deploy infrastructure and configure GitOps
  --destroy,  -d     - Tear down all infrastructure
  --validate, -v     - Validate Helm chart structure and configuration

Infrastructure: EKS cluster, Jenkins, ALB, Route53, ArgoCD, Quiz App


liav@liav-laptop:~/github/Leumi-project$ monitor-deploy -h

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


liav@liav-laptop:~/github/Leumi-project$ project-utils -h

╔════════════════════════════════════════════════════════════╗
║        Quiz App DevOps - Project Utilities                ║
╚════════════════════════════════════════════════════════════╝

Usage: project-utils [OPTIONS]

Options:
  --access,   -a       Show access information (cluster + apps)
  --argocd,   -r       Show ArgoCD status
  --open,     -o       Open web UIs in browser
  --help,     -h       Show this help
