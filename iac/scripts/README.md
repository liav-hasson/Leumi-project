Scripts Overview
================

Entry points
------------
- manage-project.sh
  - --apply / -a: full provisioning and bootstrap (Terraform, bootstrap-prod, Kubespray, bootstrap-dev)
  - --destroy / -d: graceful teardown (app cleanup, bootstrap removal, Terraform destroy)
  - --validate / -v: sanity checks for chart layout and configuration

- monitor-deployment.sh
  - Centralised log viewer. Supports: --status, --tail N, --filter, --clear.

- project-utils.sh
  - Convenience utilities: access info, Argo CD status, GitLab SSM tunnel status, open UIs.

Structure
---------
- scripts/management/operations/
  - apply.sh: tiny wrapper that calls modular helpers (lib/operations/apply/*)
  - destroy.sh: tiny wrapper that calls modular helpers (lib/operations/destroy/*)

- scripts/management/lib/operations/apply/
  - common.sh: shared helpers (notify streaming, tf output, summary)
  - git.sh: repo state check and deferred push
  - terraform.sh: terraform init/apply and prod bootstrap (ALB/ESO IRSA annotations)
  - dev-tunnels.sh: SSM tunnel management for GitLab and Kubernetes API
  - dev-kubespray.sh: Kubespray provisioning and kubeconfig handling
  - dev-argocd.sh: ArgoCD install + GitOps bootstrap hand-off
  - workflow.sh: the ordered orchestration for apply

- scripts/management/lib/operations/destroy/
  - functions.sh: audit commit, prod/dev cleanup, terraform destroy, summary

- scripts/management/lib/bootstrap/
  - deploy-kubespray.sh: concise Kubespray runner (reads central-config, validates SSH, runs playbook)

- scripts/management/lib/helpers/
  - config-loader.sh: paths, central-config, log file locations
  - logging-helpers.sh: unified logging API; format: [YYYY-mm-dd HH:MM:SS] [function] message
  - notification-helpers.sh: sends Slack notifications and mirrors them into logs
  - kube-helpers.sh, git-helpers.sh, validation-helpers.sh: misc shared helpers

Logging model
-------------
- All scripts write to log files under /tmp via logging-helpers:
  - Main:      $MAIN_LOG_FILE
  - Terraform: $TERRAFORM_LOG_FILE
  - Kubespray: $KUBESPRAY_LOG_FILE
  - Helm:      $HELM_LOG_FILE
  - Argo CD:   $ARGOCD_LOG_FILE
  - Bootstrap: $BOOTSTRAP_LOG_FILE
- Format: [time] [function] message (suitable for monitor-deployment)
- Use monitor-deployment.sh to follow or summarise logs.

Conventions
-----------
- No nested if statements in orchestration files; keep functions short and single-purpose.
- Scripts >200 lines are split into logical modules under lib/operations/*.
- Prefer Terraform/Helm managed state; scripts orchestrate, not encode configuration.

IRSA and GitOps notes
---------------------
- Prod ALB Controller and External Secrets Operator receive IRSA roles from Terraform; apply workflow adds annotations.
- Argo CD dev controller is annotated for cross-cluster deploy to prod; prod cluster registration is configured via bootstrap-dev values and Terraform outputs.

Utilities
---------
- project-utils.sh prints access URLs and syncs status; it also logs summary lines into the main log stream. It does not replace monitor-deployment.
