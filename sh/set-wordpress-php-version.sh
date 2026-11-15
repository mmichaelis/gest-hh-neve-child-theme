#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

if (($# != 1)) || [[ ! "$1" =~ ^[0-9]+\.[0-9]+$ ]]; then
  printf 'Usage: sh/set-wordpress-php-version.sh MAJOR.MINOR\n' >&2
  printf 'Example: sh/set-wordpress-php-version.sh 8.3\n' >&2
  exit 2
fi
php_version=$1

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
cd "${repo_root}"
data_dir="${repo_root}/.local-wordpress"
env_file="${data_dir}/.env"

[[ -f "${env_file}" ]] ||
  fail "No local WordPress installation was found. Run sh/install-wordpress.sh first."
[[ ! -L "${data_dir}" ]] || fail "${data_dir} must not be a symbolic link."
command -v docker >/dev/null 2>&1 ||
  fail "Docker is required. Start Docker Desktop and enable WSL integration."
docker compose version >/dev/null 2>&1 ||
  fail "Docker Compose is unavailable. Update Docker Desktop."
docker info >/dev/null 2>&1 ||
  fail "Docker is not running. Start Docker Desktop and try again."

wordpress_version="$(sed -n 's/^WORDPRESS_VERSION=//p' "${env_file}")"
[[ "${wordpress_version}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] ||
  fail "The local WordPress version is missing or invalid in ${env_file}."
php_version_count="$(grep -c '^PHP_VERSION=' "${env_file}" || true)"
[[ "${php_version_count}" == 1 ]] ||
  fail "The local PHP version setting is missing or duplicated in ${env_file}."

wordpress_image="wordpress:${wordpress_version}-php${php_version}-apache"
cli_image="wordpress:cli-php${php_version}"
docker pull "${wordpress_image}" ||
  fail "Could not pull ${wordpress_image}. Check the version and internet connection."
docker pull "${cli_image}" ||
  fail "Could not pull ${cli_image}. Check the PHP version and internet connection."

temporary_env="$(mktemp "${env_file}.XXXXXX")"
if ! sed "s/^PHP_VERSION=.*/PHP_VERSION=${php_version}/" \
  "${env_file}" >"${temporary_env}"; then
  rm -f -- "${temporary_env}"
  fail "Could not update the local PHP version."
fi
chmod 600 "${temporary_env}"
mv -- "${temporary_env}" "${env_file}"

docker compose --env-file "${env_file}" up \
  -d --no-deps --force-recreate wordpress

printf 'WordPress now uses PHP %s. The database and restored files were preserved.\n' \
  "${php_version}"
