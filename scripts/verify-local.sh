#!/usr/bin/env bash
# Runs the same checks as the pipeline, locally, before you push.
source "$(dirname "$0")/common.sh"
load_config
cd "$PROJECT_ROOT"

log "Installing dependencies"
if [ -f package-lock.json ]; then npm ci; else npm install; fi

log "Typecheck";   npm run typecheck;          ok "TypeScript compiles"
log "Unit tests";  npm test;                   ok "Tests pass"
log "Identity";    aws sts get-caller-identity; ok "AWS credentials work"
log "Synth";       npx cdk synth -c env="${CDK_ENV:-dev}" --quiet; ok "Template synthesized to cdk.out/"

ok "Local verification passed"
