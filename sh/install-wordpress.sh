#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

usage() {
  cat <<'USAGE'
Install a local WordPress copy from a database and home backup.

Usage:
  sh/install-wordpress.sh \
    --database-backup PATH \
    --home-backup PATH \
    [--wordpress-version VERSION] \
    [--php-version VERSION] \
    [--port PORT] \
    [--reset]

The WordPress version is read from the home backup unless you override it.
--reset deletes only this project's existing local database and generated
files. It never deletes the supplied backup archives.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  local -r command_name=$1
  local -r install_hint=$2

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    fail "${command_name} is required. ${install_hint}"
  fi
}

database_backup=''
home_backup=''
wordpress_override=''
php_version='8.3'
wordpress_port='8080'
reset_existing=false

while (($# > 0)); do
  case "$1" in
    --database-backup)
      (($# >= 2)) || fail "--database-backup needs a path."
      database_backup=$2
      shift 2
      ;;
    --home-backup)
      (($# >= 2)) || fail "--home-backup needs a path."
      home_backup=$2
      shift 2
      ;;
    --wordpress-version)
      (($# >= 2)) || fail "--wordpress-version needs a version."
      wordpress_override=$2
      shift 2
      ;;
    --php-version)
      (($# >= 2)) || fail "--php-version needs a version."
      php_version=$2
      shift 2
      ;;
    --port)
      (($# >= 2)) || fail "--port needs a port number."
      wordpress_port=$2
      shift 2
      ;;
    --reset)
      reset_existing=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ -n "${database_backup}" ]] || fail "Pass --database-backup PATH."
[[ -n "${home_backup}" ]] || fail "Pass --home-backup PATH."
[[ "${php_version}" =~ ^[0-9]+\.[0-9]+$ ]] ||
  fail "PHP version must use MAJOR.MINOR format, for example 8.3."
[[ "${wordpress_port}" =~ ^[0-9]+$ ]] ||
  fail "Port must be a number from 1 through 65535."
((wordpress_port >= 1 && wordpress_port <= 65535)) ||
  fail "Port must be a number from 1 through 65535."
if [[ -n "${wordpress_override}" ]]; then
  [[ "${wordpress_override}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] ||
    fail "WordPress version must use MAJOR.MINOR or MAJOR.MINOR.PATCH format."
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
cd "${repo_root}"

[[ -f "${repo_root}/compose.yaml" ]] ||
  fail "Run this script from a complete repository checkout."
data_dir="${repo_root}/.local-wordpress"
env_file="${data_dir}/.env"
content_dir="${data_dir}/wp-content"
if [[ -L "${data_dir}" ]]; then
  fail "${data_dir} must not be a symbolic link."
fi

require_command docker "Install Docker Desktop and enable its WSL integration."
require_command python3 "Install Python 3.10 or later in WSL."
require_command curl "Install curl in WSL."
require_command openssl "Install OpenSSL in WSL."
require_command realpath "Install GNU coreutils in WSL."
require_command pnpm "Install PNPM 12 and run pnpm install --frozen-lockfile."
require_command node "Install Node.js 26."

docker compose version >/dev/null 2>&1 ||
  fail "Docker Compose is unavailable. Update Docker Desktop and its WSL integration."
docker info >/dev/null 2>&1 ||
  fail "Docker is not running. Start Docker Desktop and check its WSL integration."

node_version="$(node --version)"
node_major="${node_version#v}"
node_major="${node_major%%.*}"
[[ "${node_major}" == 26 ]] ||
  fail "Node.js 26 is required to build the theme; found ${node_version}."
pnpm_version="$(pnpm --version)"
[[ "${pnpm_version}" == 12.* ]] ||
  fail "PNPM 12 is required to build the theme; found ${pnpm_version}."
[[ -e "${repo_root}/node_modules/minimist" ]] ||
  fail "Project dependencies are missing. Run pnpm install --frozen-lockfile."

database_backup="$(realpath -e -- "${database_backup}")"
home_backup="$(realpath -e -- "${home_backup}")"
[[ -f "${database_backup}" ]] || fail "Database backup is not a regular file."
[[ -f "${home_backup}" ]] || fail "Home backup is not a regular file."
[[ "${database_backup}" != "${home_backup}" ]] ||
  fail "Database and home backups must be different files."

data_dir_resolved="$(realpath -m -- "${data_dir}")"
for backup_path in "${database_backup}" "${home_backup}"; do
  case "${backup_path}/" in
    "${data_dir_resolved}/"*)
      fail "Keep backup archives outside ${data_dir} so --reset cannot remove them."
      ;;
  esac
done

archive_helper="${repo_root}/sh/wordpress_archive.py"
home_info="$(python3 "${archive_helper}" home-info "${home_backup}")" ||
  fail "Could not inspect the home backup."
IFS=$'\t' read -r detected_wordpress_version archive_root <<<"${home_info}"
[[ -n "${detected_wordpress_version}" && -n "${archive_root}" ]] ||
  fail "Could not detect the WordPress root and version in the home backup."
wordpress_version="${wordpress_override:-${detected_wordpress_version}}"

database_info="$(python3 "${archive_helper}" database-info "${database_backup}")" ||
  fail "Could not inspect the database backup."
IFS=$'\t' read -r database_member database_name table_prefix <<<"${database_info}"
[[ -n "${database_member}" && -n "${database_name}" && -n "${table_prefix}" ]] ||
  fail "Could not detect the database name and WordPress table prefix."

if [[ -e "${data_dir}" && "${reset_existing}" != true ]]; then
  fail "Local data already exists. Stop the site and pass --reset only if you want to delete it."
fi

printf 'Building the child theme...\n'
pnpm --silent build
[[ -f "${repo_root}/build/gest-hh-neve-child/style.css" ]] ||
  fail "The child theme build did not create build/gest-hh-neve-child/style.css."

wordpress_image="wordpress:${wordpress_version}-php${php_version}-apache"
cli_image="wordpress:cli-php${php_version}"
printf 'Checking required Docker images...\n'
docker pull "${wordpress_image}" ||
  fail "Could not pull ${wordpress_image}. Check the version and internet connection."
docker pull "${cli_image}" ||
  fail "Could not pull ${cli_image}. Check the PHP version and internet connection."
docker pull mariadb:10.11.4 ||
  fail "Could not pull mariadb:10.11.4. Check the internet connection."

stop_existing_stack() {
  if [[ -f "${env_file}" ]]; then
    docker compose --env-file "${env_file}" down --remove-orphans
  else
    docker compose down --remove-orphans
  fi
}

claim_restored_content() {
  [[ -d "${content_dir}" ]] || return 0
  [[ ! -L "${content_dir}" ]] ||
    fail "Refusing to change ownership of a symbolic-link content directory."
  local host_owner
  local host_uid
  local host_gid
  host_uid="$(id -u)"
  host_gid="$(id -g)"
  host_owner="${host_uid}:${host_gid}"
  docker run --rm --network none --user 0:0 \
    --volume "${content_dir}:/restored-content" \
    --entrypoint sh "${wordpress_image}" -c \
    'chown -R "$1" /restored-content && chmod -R u+rwX /restored-content' \
    sh "${host_owner}" ||
    fail "Could not prepare restored files for reset."
}

check_local_port() {
  if ! python3 -c '
import socket
import sys

sock = socket.socket()
try:
    sock.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    sock.close()
' "${wordpress_port}"; then
    fail "Local port ${wordpress_port} is already in use. Choose another with --port."
  fi
}

remove_local_data() {
  stop_existing_stack
  claim_restored_content
  docker compose down --volumes --remove-orphans
  [[ "${data_dir}" == "${repo_root}/.local-wordpress" ]] ||
    fail "Refusing to remove an unexpected local data path."
  rm -rf -- "${data_dir}"
}

if [[ -e "${data_dir}" || "${reset_existing}" == true ]]; then
  remove_local_data
fi
check_local_port

mkdir -p "${data_dir}" "${content_dir}"
umask 077
database_password="$(openssl rand -hex 32)"
root_password="$(openssl rand -hex 32)"
cat >"${env_file}" <<EOF
WORDPRESS_VERSION=${wordpress_version}
PHP_VERSION=${php_version}
WORDPRESS_PORT=${wordpress_port}
WORDPRESS_TABLE_PREFIX=${table_prefix}
LOCAL_DB_NAME=${database_name}
LOCAL_DB_USER=gest_local
LOCAL_DB_PASSWORD=${database_password}
MARIADB_ROOT_PASSWORD=${root_password}
EOF
chmod 600 "${env_file}"

compose() {
  docker compose --env-file "${env_file}" "$@"
}

if ! docker compose --env-file "${env_file}" config --quiet; then
  fail "Docker Compose configuration is invalid. See the error above."
fi

printf 'Restoring themes, plugins, and uploads from the home backup...\n'
python3 "${archive_helper}" extract-home \
  "${home_backup}" "${content_dir}" "${detected_wordpress_version}" "${archive_root}" ||
  fail "Could not safely restore WordPress content."

printf 'Starting the local database...\n'
compose up -d database
database_ready=false
attempt=0
while ((attempt < 60)); do
  attempt=$((attempt + 1))
  if docker compose --env-file "${env_file}" exec -T \
    -e "MYSQL_PWD=${root_password}" database \
    mariadb --user=root --batch --skip-column-names \
    --execute='SELECT 1' >/dev/null 2>&1; then
    database_ready=true
    break
  fi
  sleep 2
done
if [[ "${database_ready}" != true ]]; then
  compose logs --no-color database | tail -n 40 >&2
  fail "The database did not become ready. See the database logs above."
fi

printf 'Importing the database backup...\n'
if ! python3 "${archive_helper}" stream-database \
  "${database_backup}" "${database_member}" |
  docker compose --env-file "${env_file}" exec -T \
    -e "MYSQL_PWD=${root_password}" database \
    mariadb --user=root "${database_name}" 2>"${data_dir}/database-import.log"; then
  chmod 600 "${data_dir}/database-import.log"
  fail "Database import failed. Private error details are in ${data_dir}/database-import.log."
fi

printf 'Starting WordPress on 127.0.0.1:%s...\n' "${wordpress_port}"
compose up -d wordpress
local_url="http://localhost:${wordpress_port}"
wordpress_ready=false
attempt=0
while ((attempt < 60)); do
  attempt=$((attempt + 1))
  http_status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --max-time 5 "http://127.0.0.1:${wordpress_port}/" || true)"
  if [[ "${http_status}" =~ ^[23][0-9][0-9]$ ]]; then
    wordpress_ready=true
    break
  fi
  sleep 2
done
[[ "${wordpress_ready}" == true ]] ||
  fail "WordPress did not answer on 127.0.0.1:${wordpress_port}. Check docker compose logs."

wp_cli() {
  compose run --rm --no-deps cli \
    --path=/var/www/html --skip-plugins --skip-themes "$@"
}

if ! docker compose --env-file "${env_file}" run --rm --no-deps cli \
  --path=/var/www/html --skip-plugins --skip-themes core is-installed \
  >/dev/null; then
  fail "WordPress could not read the imported database. Verify its table prefix."
fi

database_query() {
  compose exec -T -e "MYSQL_PWD=${database_password}" database \
    mariadb --user=gest_local --batch --skip-column-names \
    --database="${database_name}" --execute="$1"
}

source_home="$(database_query \
  "SELECT option_value FROM \`${table_prefix}options\` WHERE option_name = 'home' LIMIT 1;")"
source_siteurl="$(database_query \
  "SELECT option_value FROM \`${table_prefix}options\` WHERE option_name = 'siteurl' LIMIT 1;")"
[[ -n "${source_home}" && -n "${source_siteurl}" ]] ||
  fail "Could not read the original WordPress URLs from the imported database."
for source_url in "${source_home}" "${source_siteurl}"; do
  if [[ ( "${source_url}" == http://* || "${source_url}" == https://* ) &&
    "${source_url}" != "${local_url}" ]]; then
    wp_cli search-replace "${source_url}" "${local_url}" \
      --all-tables --precise --skip-columns=guid --report-changed-only >/dev/null
  fi
done
wp_cli option update home "${local_url}" >/dev/null
wp_cli option update siteurl "${local_url}" >/dev/null

# shellcheck disable=SC2016 # PHP variables must not expand in Bash.
if ! docker compose --env-file "${env_file}" run --rm --no-deps cli \
  --path=/var/www/html --skip-plugins --skip-themes eval \
  'if (!get_role("gest_local_reviewer")) { $caps = get_role("subscriber")->capabilities; $caps["read_private_pages"] = true; $caps["read_private_posts"] = true; add_role("gest_local_reviewer", "Local reviewer", $caps); }'; then
  fail "Could not create the local read-only reviewer role."
fi

reviewer_login='gest-local-reviewer'
reviewer_email='gest-local-reviewer@example.invalid'
reviewer_password="$(openssl rand -hex 24)"
if docker compose --env-file "${env_file}" run --rm --no-deps cli \
  --path=/var/www/html --skip-plugins --skip-themes \
  user get "${reviewer_login}" --field=ID >/dev/null 2>&1; then
  wp_cli user update "${reviewer_login}" \
    --user_pass="${reviewer_password}" \
    --user_email="${reviewer_email}" \
    --role=gest_local_reviewer \
    --quiet
else
  wp_cli user create "${reviewer_login}" "${reviewer_email}" \
    --user_pass="${reviewer_password}" \
    --role=gest_local_reviewer \
    --quiet
fi

credentials_file="${data_dir}/credentials.txt"
{
  printf 'Site: %s\n' "${local_url}"
  printf 'Login: %s\n' "${reviewer_login}"
  printf 'Password: %s\n' "${reviewer_password}"
} >"${credentials_file}"
chmod 600 "${credentials_file}"

wp_cli plugin list --fields=name,status,version --format=table \
  >"${data_dir}/plugins.txt"
chmod 600 "${data_dir}/plugins.txt"

# shellcheck disable=SC2016 # PHP variables must not expand in Bash.
if ! docker compose --env-file "${env_file}" run --rm --no-deps cli \
  --path=/var/www/html --skip-plugins --skip-themes eval \
  '$blocked = apply_filters("pre_wp_mail", null, []); if ($blocked !== false) { exit(1); }'; then
  fail "The local email blocker did not load."
fi

response_headers="$(curl --silent --show-error --dump-header - --output /dev/null \
  --max-time 5 "${local_url}/")"
grep -Fq 'Content-Security-Policy:' <<<"${response_headers}" ||
  fail "The local browser network policy is missing from the site response."
grep -Fq 'https://fonts.googleapis.com' <<<"${response_headers}" ||
  fail "The local browser policy does not allow Google Fonts stylesheets."
grep -Fq 'https://fonts.gstatic.com' <<<"${response_headers}" ||
  fail "The local browser policy does not allow Google Fonts files."

printf '\nLocal WordPress is ready: %s\n' "${local_url}"
printf 'Reviewer credentials are stored in %s (owner-readable only).\n' "${credentials_file}"
printf 'Plugin inventory is stored in %s.\n' "${data_dir}/plugins.txt"
printf 'To stop the site, run: docker compose --env-file %s down\n' "${env_file}"
printf 'The site will not start automatically after a reboot.\n'
