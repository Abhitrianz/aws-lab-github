#!/usr/bin/env bash
# One-time AWS setup. Idempotent: safe to run more than once.
#   1. GitHub OIDC identity provider
#   2. IAM role trusted by your repo/branch, with least-privilege policy
#   3. CDK bootstrap for the account/region
#   4. GitHub repository variables (if the gh CLI is available)
source "$(dirname "$0")/common.sh"
load_config

"$SCRIPT_DIR/check-prereqs.sh"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ACCOUNT_ID
OIDC_URL="token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

log "Account: $ACCOUNT_ID | Region: $AWS_REGION | Repo: $GITHUB_ORG/$GITHUB_REPO@$BRANCH"

# ---- 1. OIDC provider -------------------------------------------------------
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  ok "OIDC provider already exists"
else
  log "Creating GitHub OIDC provider"
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
  ok "OIDC provider created"
fi

# ---- 2. IAM role ------------------------------------------------------------
TRUST_FILE="$PROJECT_ROOT/iam/github-trust-policy.generated.json"
PERM_FILE="$PROJECT_ROOT/iam/github-permissions-policy.generated.json"
render_template "$PROJECT_ROOT/iam/github-trust-policy.template.json" "$TRUST_FILE"
render_template "$PROJECT_ROOT/iam/github-permissions-policy.template.json" "$PERM_FILE"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  log "Role exists; updating trust policy"
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://$(native_path "$TRUST_FILE")"
else
  log "Creating role $ROLE_NAME"
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --description "Assumed by GitHub Actions ($GITHUB_ORG/$GITHUB_REPO) via OIDC" \
    --max-session-duration 3600 \
    --assume-role-policy-document "file://$(native_path "$TRUST_FILE")" >/dev/null
fi

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name gh-cdk-deploy-policy \
  --policy-document "file://$(native_path "$PERM_FILE")"
ok "Role ready: $ROLE_ARN"

# ---- 3. CDK bootstrap -------------------------------------------------------
log "Installing npm dependencies"
cd "$PROJECT_ROOT"
if [ -f package-lock.json ]; then npm ci; else npm install; fi

log "Bootstrapping CDK in aws://$ACCOUNT_ID/$AWS_REGION"
npx cdk bootstrap "aws://${ACCOUNT_ID}/${AWS_REGION}"
ok "CDK bootstrap complete"

# ---- 4. GitHub repository variables -----------------------------------------
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  log "Setting GitHub repository variables with gh CLI"
  gh variable set AWS_ROLE_ARN   --repo "$GITHUB_ORG/$GITHUB_REPO" --body "$ROLE_ARN"
  gh variable set AWS_REGION     --repo "$GITHUB_ORG/$GITHUB_REPO" --body "$AWS_REGION"
  gh variable set AWS_ACCOUNT_ID --repo "$GITHUB_ORG/$GITHUB_REPO" --body "$ACCOUNT_ID"
  ok "Repository variables set"
else
  warn "gh CLI not available or not logged in. Add these manually under"
  warn "GitHub repo -> Settings -> Secrets and variables -> Actions -> Variables:"
fi

cat <<SUMMARY

==================================================================
 AWS setup complete
------------------------------------------------------------------
 AWS_ROLE_ARN   = $ROLE_ARN
 AWS_REGION     = $AWS_REGION
 AWS_ACCOUNT_ID = $ACCOUNT_ID
------------------------------------------------------------------
 Next: commit package-lock.json, push to GitHub, then run the
 "CDK Connectivity Test" workflow with stage = identity.
==================================================================
SUMMARY
