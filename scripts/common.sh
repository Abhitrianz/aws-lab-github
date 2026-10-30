#!/usr/bin/env bash
# Shared helpers for setup/verify/teardown scripts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

load_config() {
  local cfg="$SCRIPT_DIR/config.env"
  [ -f "$cfg" ] || fail "Missing $cfg. Copy scripts/config.env.example to scripts/config.env and edit it."
  # shellcheck disable=SC1090
  set -a; source "$cfg"; set +a

  : "${GITHUB_ORG:?GITHUB_ORG must be set in config.env}"
  : "${GITHUB_REPO:?GITHUB_REPO must be set in config.env}"
  : "${BRANCH:=main}"
  : "${AWS_REGION:?AWS_REGION must be set in config.env}"
  : "${ROLE_NAME:=gh-cdk-deploy-role}"

  if [ -z "${AWS_PROFILE:-}" ]; then unset AWS_PROFILE; fi
  export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' not found. $2"
}

node_major() { node -p 'process.versions.node.split(".")[0]'; }

render_template() {
  # render_template <template> <output>
  sed -e "s|__ACCOUNT_ID__|$ACCOUNT_ID|g" \
      -e "s|__REGION__|$AWS_REGION|g" \
      -e "s|__GITHUB_ORG__|$GITHUB_ORG|g" \
      -e "s|__GITHUB_REPO__|$GITHUB_REPO|g" \
      -e "s|__BRANCH__|$BRANCH|g" \
      "$1" > "$2"
}
