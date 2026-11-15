#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

failed=0

warn_skip() {
  local -r check_name=$1
  local -r reason=$2
  printf 'WARNING: Skipping %s: %s\n' "${check_name}" "${reason}" >&2
}

run_check() {
  local -r check_name=$1
  shift

  printf '==> %s\n' "${check_name}"
  if "$@"; then
    printf 'PASS: %s\n' "${check_name}"
  else
    local -r status=$?
    printf 'FAIL: %s (exit code %s)\n' "${check_name}" "${status}" >&2
    failed=1
  fi
}

run_pnpm_check() {
  local -r check_name=$1
  local -r executable=$2
  local -r script_name=$3

  if ! command -v pnpm >/dev/null 2>&1; then
    warn_skip "${check_name}" "pnpm is unavailable"
  elif ! pnpm exec "${executable}" --version >/dev/null 2>&1; then
    warn_skip "${check_name}" "${executable} is not installed"
  else
    run_check "${check_name}" pnpm run "${script_name}"
  fi
}

run_pnpm_check "ESLint" "eslint" "eslint"
run_pnpm_check "TypeScript" "tsc" "typecheck"
run_pnpm_check "Prettier" "prettier" "formatcheck"
run_pnpm_check "Markdownlint" "markdownlint-cli2" "markdownlint"
run_pnpm_check "Stylelint" "stylelint" "stylelint"

actionlint_local_bin="${HOME:-}/.local/bin/actionlint"
if command -v actionlint >/dev/null 2>&1; then
  run_check "actionlint" actionlint
elif [[ -n "${HOME:-}" && -x "${actionlint_local_bin}" ]]; then
  run_check "actionlint" "${actionlint_local_bin}"
else
  warn_skip "actionlint" "run sh/install-actionlint.sh to install the pinned release"
fi

if command -v shellcheck >/dev/null 2>&1; then
  run_check "ShellCheck" shellcheck sh/*.sh bin/*.sh
else
  warn_skip "ShellCheck" "the shellcheck executable is unavailable"
fi

if (( failed != 0 )); then
  printf 'One or more available checks failed.\n' >&2
  exit 1
fi

printf 'All available checks passed.\n'
