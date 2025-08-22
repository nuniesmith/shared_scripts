#!/usr/bin/env bash
# Purpose: Environment & mode detection, .env loading (idempotent)
# Exports: detect_mode, load_dotenv, require_cmd, PROJECT_ROOT, SCRIPT_ROOT

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_ROOT/.." && pwd)"

# shellcheck source=log.sh
[[ -f "$SCRIPT_ROOT/log.sh" ]] && source "$SCRIPT_ROOT/log.sh"

: "${FKS_MODE:=}"
: "${CI:=false}"

_detect_ci() { [[ "${GITHUB_ACTIONS:-}" == "true" || "${CI}" == "true" ]]; }

detect_mode() {
  if [[ -n "$FKS_MODE" ]]; then echo "$FKS_MODE"; return 0; fi
  if _detect_ci; then echo "ci"; return 0; fi
  if [[ -n "${FKS_DEV:-}" ]]; then echo "dev"; return 0; fi
  echo "local"
}

# Load key=value lines from a .env style file
load_dotenv() {
  local file=${1:-.env}
  [[ -f "$file" ]] || { log_warn ".env file $file not found" || true; return 0; }
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "$line"
    fi
  done <"$file"
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { log_error "Missing required command: $c"; return 127; }
  done
}

export -f detect_mode load_dotenv require_cmd
