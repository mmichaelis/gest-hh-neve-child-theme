#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

if (($# < 1 || $# > 2)) || [[ "$1" != --delete-data ]] ||
  { (($# == 2)) && [[ "$2" != --yes ]]; }; then
  printf 'Usage: sh/remove-wordpress.sh --delete-data [--yes]\n' >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
cd "${repo_root}"
data_dir="${repo_root}/.local-wordpress"

[[ "${data_dir}" == "${repo_root}/.local-wordpress" ]] ||
  fail "Refusing to remove an unexpected local data path."
[[ ! -L "${data_dir}" ]] || fail "${data_dir} must not be a symbolic link."
command -v docker >/dev/null 2>&1 ||
  fail "Docker is required. Start Docker Desktop and enable WSL integration."
docker compose version >/dev/null 2>&1 ||
  fail "Docker Compose is unavailable. Update Docker Desktop."
docker info >/dev/null 2>&1 ||
  fail "Docker is not running. Start Docker Desktop and try again."

if (($# == 1)); then
  printf 'This will permanently delete the local WordPress database, site files, and credentials.\n'
  printf 'The supplied backup archives will not be deleted.\n'
  printf 'Type DELETE to continue: '
  read -r confirmation
  [[ "${confirmation}" == DELETE ]] || {
    printf 'Canceled. No local data was deleted.\n'
    exit 0
  }
fi

env_file="${data_dir}/.env"
content_dir="${data_dir}/wp-content"
if [[ -f "${env_file}" ]]; then
  docker compose --env-file "${env_file}" stop wordpress
else
  wordpress_version='7.1.4'
  php_version='8.3'
fi

if [[ -d "${content_dir}" ]]; then
  [[ ! -L "${content_dir}" ]] ||
    fail "Refusing to change ownership of a symbolic-link content directory."
  if [[ -f "${env_file}" ]]; then
    wordpress_version="$(sed -n 's/^WORDPRESS_VERSION=//p' "${env_file}")"
    php_version="$(sed -n 's/^PHP_VERSION=//p' "${env_file}")"
  fi
  [[ "${wordpress_version}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] ||
    fail "The local WordPress version in ${env_file} is invalid."
  [[ "${php_version}" =~ ^[0-9]+\.[0-9]+$ ]] ||
    fail "The local PHP version in ${env_file} is invalid."
  host_uid="$(id -u)"
  host_gid="$(id -g)"
  host_owner="${host_uid}:${host_gid}"
  docker run --rm --network none --user 0:0 \
    --volume "${content_dir}:/restored-content" \
    --entrypoint sh \
    "wordpress:${wordpress_version}-php${php_version}-apache" -c \
    'chown -R "$1" /restored-content && chmod -R u+rwX /restored-content' \
    sh "${host_owner}" ||
    fail "Could not prepare restored files for removal."
fi

if [[ -f "${env_file}" ]]; then
  docker compose --env-file "${env_file}" down --volumes --remove-orphans
else
  docker compose down --volumes --remove-orphans
fi

if [[ -e "${data_dir}" ]]; then
  rm -rf -- "${data_dir}"
fi

printf 'Local WordPress containers, volumes, and generated files were removed.\n'
printf 'The supplied backup archives and the built theme were left untouched.\n'
