#!/usr/bin/env bash

set -o errexit   # abort on nonzero exit status
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

# Respect GitHub Actions debug mode.
declare -ir MODE_DEBUG=${RUNNER_DEBUG:-0}

if (( MODE_DEBUG )); then
  set -o xtrace
else
  set +o xtrace
fi

pnpm --silent about "${@}"
