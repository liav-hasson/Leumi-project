#!/bin/bash
# operations/apply.sh
# Orchestrates the infrastructure apply workflow using modular helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "$SCRIPT_DIR/../lib/operations" && pwd)"

# exporting scripts called by apply execute
source "$LIB_ROOT/apply/common.sh"
source "$LIB_ROOT/apply/terraform.sh"
source "$LIB_ROOT/apply/inject-argocd-values.sh"
source "$LIB_ROOT/apply/workflow.sh"
source "$SCRIPT_DIR/../lib/helpers/logging-helpers.sh"
source "$SCRIPT_DIR/../lib/helpers/validation-helpers.sh"

# calls bootstrap/operations/apply/workflow.sh
terraform-apply() {
    apply_execute
}
