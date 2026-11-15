#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly version="1.7.12"

if (( $# > 1 )); then
  printf 'Usage: %s [install-directory]\n' "$0" >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  printf 'The GitHub CLI (gh) is required to download and verify actionlint.\n' >&2
  exit 127
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'This installer supports Linux only.\n' >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64)
    readonly arch="amd64"
    ;;
  aarch64 | arm64)
    readonly arch="arm64"
    ;;
  *)
    printf 'Unsupported Linux architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

if (( $# == 1 )); then
  install_dir=$1
elif [[ -n "${HOME:-}" ]]; then
  install_dir="${HOME}/.local/bin"
else
  printf 'HOME is unset; provide an install directory.\n' >&2
  exit 1
fi

if [[ -z "${install_dir}" ]]; then
  printf 'The install directory must not be empty.\n' >&2
  exit 2
fi

readonly archive_name="actionlint_${version}_linux_${arch}.tar.gz"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "${tmp_dir}"' EXIT

gh release download "v${version}" \
  --repo rhysd/actionlint \
  --pattern "${archive_name}" \
  --dir "${tmp_dir}"
gh attestation verify --repo rhysd/actionlint "${tmp_dir}/${archive_name}"
tar -xzf "${tmp_dir}/${archive_name}" -C "${tmp_dir}" actionlint

mkdir -p "${install_dir}"
install -m 0755 "${tmp_dir}/actionlint" "${install_dir}/actionlint"
printf 'Installed actionlint v%s to %s/actionlint\n' "${version}" "${install_dir}"
