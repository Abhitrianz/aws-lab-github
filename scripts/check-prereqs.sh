#!/usr/bin/env bash
# Verifies local tools and AWS credentials before running setup.
source "$(dirname "$0")/common.sh"
load_config

log "Checking local prerequisites"

require_cmd node "Install Node.js 22 LTS or newer: https://nodejs.org"
[ "$(node_major)" -ge 22 ] || fail "Node.js $(node --version) found; version 22 or newer is required."
ok "Node.js $(node --version)"

require_cmd npm "npm ships with Node.js."
ok "npm $(npm --version)"

require_cmd aws "Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
aws --version 2>&1 | grep -q 'aws-cli/2' || fail "AWS CLI v2 is required. Found: $(aws --version 2>&1)"
ok "$(aws --version 2>&1)"

require_cmd git "Install git."
ok "git $(git --version | awk '{print $3}')"

log "Checking AWS credentials"
IDENTITY=$(aws sts get-caller-identity --output json) || fail "AWS credentials are not configured. Run 'aws configure' or 'aws sso login'."
echo "$IDENTITY"
ok "AWS credentials work (region: $AWS_REGION)"

if command -v gh >/dev/null 2>&1; then
  ok "GitHub CLI found (setup can set repository variables automatically)"
else
  warn "GitHub CLI 'gh' not found. You will set repository variables manually."
fi

ok "All prerequisites satisfied"
