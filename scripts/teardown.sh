#!/usr/bin/env bash
# Removes what this project created.
#   ./scripts/teardown.sh            -> destroys the test stack only
#   ./scripts/teardown.sh --all      -> also deletes the IAM role
#   ./scripts/teardown.sh --all --oidc -> also deletes the OIDC provider
# The CDKToolkit (bootstrap) stack is never removed automatically,
# because other CDK apps in the account may depend on it.
source "$(dirname "$0")/common.sh"
load_config
cd "$PROJECT_ROOT"

DELETE_ROLE=false; DELETE_OIDC=false
for arg in "$@"; do
  case "$arg" in
    --all)  DELETE_ROLE=true ;;
    --oidc) DELETE_OIDC=true ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

log "Destroying CDK stack(s) for env=${CDK_ENV:-dev}"
[ -d node_modules ] || npm install
npx cdk destroy --all -c env="${CDK_ENV:-dev}" --force
ok "Stack destroyed"

if $DELETE_ROLE; then
  if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name gh-cdk-deploy-policy || true
    aws iam delete-role --role-name "$ROLE_NAME"
    ok "Role $ROLE_NAME deleted"
  else
    warn "Role $ROLE_NAME not found"
  fi
fi

if $DELETE_OIDC; then
  warn "Deleting the GitHub OIDC provider breaks ANY other repo in this account that uses it."
  read -r -p "Type 'delete' to continue: " confirm
  if [ "$confirm" = "delete" ]; then
    aws iam delete-open-id-connect-provider \
      --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    ok "OIDC provider deleted"
  else
    warn "Skipped OIDC provider deletion"
  fi
fi

log "To remove CDK bootstrap too, delete the CDKToolkit stack and its S3 bucket manually."
