#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Bash Options
# ------------------------------------------------------------------------------

set -o errexit   # abort on nonzero exit status
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

# ------------------------------------------------------------------------------
# Initialization: GitHub Actions Environment Awareness
# ------------------------------------------------------------------------------

# Respect GitHub Actions debug mode.
declare -ir MODE_DEBUG=${RUNNER_DEBUG:-0}

# Respect GitHub Actions verbosity also for logging bash script.
if (( MODE_DEBUG )); then
  set -o xtrace
else
  set +o xtrace
fi

# Detect if running in GitHub CI Environment.
MODE_CI=$( [[ "${CI:-false}" == "true" ]] && echo 1 || echo 0 )
declare -ir MODE_CI

# ------------------------------------------------------------------------------
# Initialization: Output Folder
# ------------------------------------------------------------------------------

output_path="${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}"
declare -r output_path

# ------------------------------------------------------------------------------
# Initialization: Helper Methods
# ------------------------------------------------------------------------------

# Logs the given informational message.
# May also be used to pipe output to this log.
#
# If running in CI, all output is sent to stderr, so that the output to
# stdout can be used to retrieve the JSON information.
function log_info() {
  local -r msg=${1:-$(</dev/stdin)}
  if [[ -z "${msg}" ]]; then
    # Nothing to print
    return
  fi
  local logMsg
  printf -v logMsg "[INFO] %s\n" "${msg}"
  if (( MODE_CI )); then
    echo "${logMsg}" >&2
  else
    echo "${logMsg}"
  fi
}

# Writes directly to stdout. May also be used to pipe output to here.
# shellcheck disable=SC2120
function write_out() {
  local -r msg=${1:-$(</dev/stdin)}
  printf "%s\n" "${msg}"
}

# Logs the given error message.
# May also be used to pipe output to this log.
function log_error() {
  local -r msg=${1:-$(</dev/stdin)}
  printf "[ERROR] %s\n" "${msg}" >&2
}

# Outputs the given error (if any) and exits the script with a non-zero status.
function throw_error() {
  local -r msg=${1:-}
  [ -n "${msg}" ] && log_error "${msg}"
  exit 1
}

# Retrieve the repository URL (without trailing .git).
function get_repository_url() {
  local -r gitHubServerUrl="${GITHUB_SERVER_URL:-}"
  local -r gitHubRepository="${GITHUB_REPOSITORY:-}"
  # Prefer GitHub Actions environment variables.
  if [ -n "${gitHubServerUrl}" ] && [ -n "${gitHubRepository}" ]; then
    echo "${gitHubServerUrl}/${gitHubRepository}"
    return
  fi

  # Fallback, especially for local execution.
  local -r repoUrl=$(git config --get remote.origin.url)
  if [ -z "${repoUrl}" ]; then
    throw_error "Failed to determine repository URL."
  fi
  echo "${repoUrl%.git}"
}

function get_github_compare_url() {
  local -r repoUrl=$(get_repository_url)
  local -r previousCompareRef=${1:-}
  local -r currentCompareRef=${2:-}
  if [ -z "${previousCompareRef}" ] || [ -z "${currentCompareRef}" ]; then
    throw_error "Missing required arguments for GitHub Compare URL."
  fi

  echo "${repoUrl}/compare/${previousCompareRef}...${currentCompareRef}"
}

# ------------------------------------------------------------------------------
# Initialization: Parse CLI Options
# ------------------------------------------------------------------------------

OPTIONS=$(getopt --options "hj::pt:" --longoptions "help,json::,push,type:" --name "${BASH_ARGV0}" -- "$@" || exit 1)
declare -r OPTIONS

declare help=0
# Default to output JSON results in CI mode.
declare -i json=${MODE_CI}
# If not empty, write the JSON results to the given path.
declare jsonPath=""
declare type="unset"
declare push=0

eval set -- "${OPTIONS}"
while true; do
  if (( MODE_DEBUG )); then
    log_info "Processing Argument: ${1:-EOA}"
  fi
  case "${1:-EOA}" in
    -h | --help)
      help=1
      ;;
    -j | --json)
      json=1
      # If optional argument to JSON (given as --json=PATH), the second
      # value exists, but is empty, thus, perfectly matches our scenario
      # for one to write to stdout.
      jsonPath="${2}"
      shift
      ;;
    -p | --push)
      push=1
      ;;
    -t | --type)
      type="${2@L}"
      shift
      ;;
    --)
      shift
      break
      ;;
    EOA)
      # End of Arguments
      break
      ;;
    *)
      throw_error "Internal error! Unhandled valid option: '${1}'."
      ;;
  esac
  shift
done

#
# --help takes precedence over all other options.
#

if (( help )); then
# -------1---------2---------3---------4---------5---------6---------7---------8
  cat << end_help | write_out
Usage: ${BASH_ARGV0} [OPTIONS] --type=<TYPE>

Options:

  -d, --dry-run  Dry run mode.
  -h, --help     Display this help message.
  -j, --json     Enable JSON result output. If an optional path is given, write
                 to that file. Otherwise, JSON will be written to stdout
                 instead.
  -p, --push     Push changes.
  -t, --type     (required) Release type: snapshot (alias for prerelease),
                 patch, minor, or major.

Examples:

${BASH_ARGV0} --type=patch
${BASH_ARGV0} --type=patch --push
${BASH_ARGV0} --type=patch --json
${BASH_ARGV0} --type=patch --json=my/path/result.json
end_help
# -------1---------2---------3---------4---------5---------6---------7---------8

  exit 0
fi

#
# Parse required --type Parameter
#

declare -i isSnapshotRelease=0

case "${type}" in
  snapshot | prerelease)
    log_info "Releasing a snapshot version."
    type="prerelease"
    isSnapshotRelease=1
    ;;
  patch | minor | major)
    ;;
  unset)
    throw_error "Required argument --type is missing."
    ;;
  *)
    throw_error "Invalid release type: '${type}'."
    ;;
esac


# ------------------------------------------------------------------------------
# Validation: Ensure that the working directory is clean.
# ------------------------------------------------------------------------------

if [ -z "$(git --no-pager status --untracked-files=no --porcelain)" ]; then
  log_info "Working directory clean."
else
  log_error "Working directory is dirty. Aborting."
  git --no-pager status --untracked-files=no | log_error
  throw_error
fi

# ------------------------------------------------------------------------------
# Initialization: Git Information
# ------------------------------------------------------------------------------

# Ensure we are latest. This also allows to re-run the release workflow with
# the same stored commit hash, if needed.
git fetch --quiet | log_info

log_info "Initialization: Git Information"

currentRef=$(git rev-parse HEAD)
declare -r currentRef

log_info "Fetching previous release information."

# Example Output: e3cfac0e19c5cfaf3dca11d05a321d952cda64ad        refs/tags/v1.1.0
lastReleaseInformation=$(git --no-pager ls-remote --tags --quiet|grep --perl-regexp "^\\S+\\s+refs/tags/v[.0-9]+$"|tail --lines=1)
declare -r lastReleaseInformation
previousReleaseHash=$(cut --fields=1 <<< "${lastReleaseInformation}")
declare -r previousReleaseHash
previousReleaseVersion=$(grep --only-matching --perl-regexp "v[.0-9]+$" <<< "${lastReleaseInformation}")
declare -r previousReleaseVersion

# ------------------------------------------------------------------------------
# Initialization: Project Information
# ------------------------------------------------------------------------------

log_info "Initialization: Project Information"

projectName=$(pnpm --silent about name)
declare -r projectName
declare -r artifactName="${projectName}.zip"
declare -r artifactPath="${output_path}/${artifactName}"

currentVersion=$(pnpm --silent about version)
declare -r currentVersion
currentIsSnapshot=$( [[ "${currentVersion}" =~ .*rc.* ]] && echo 1 || echo 0 )
declare -ir currentIsSnapshot

# ------------------------------------------------------------------------------
# Perform: Create Release
# ------------------------------------------------------------------------------

if (( isSnapshotRelease == 0 || currentIsSnapshot == 0 )); then
  log_info "Perform: Releasing a ${type} version."

  releaseVersion="$(tail --lines=1 <<< "$(pnpm version "${type}" --preid "rc" --no-git-tag-version || throw_error "Failed to create release version.")")"

  git commit --all --message "chore: release ${type}: ${releaseVersion}" | log_info
  releaseHash="$(git rev-parse HEAD)"

  log_info "Released a ${type} version: ${releaseVersion} (${releaseHash})"
else
  # No need to perform a release, we already have a yet unused snapshot
  # version. Just build the project.
  log_info "Skipping release, as we are already in a snapshot version. Just building."

  releaseVersion="${currentVersion}"
  releaseHash="${currentRef}"

  pnpm build | log_info
fi

declare -r releaseVersion
declare -r releaseHash

# Execute in Subshell to avoid polluting the working directory.
(
  cd build | log_info
  zip add --quiet --recurse-paths -9 --archive-comment "${artifactPath}" . <<< "${type^} release ${releaseVersion} of ${projectName}." | log_info
)

sizeInfo="$(du --summarize --human-readable "${artifactName}" | cut -f1)"
declare -r sizeInfo
log_info "Created Release Artifact: ${artifactName} (path: ${artifactPath}, size: ${sizeInfo})"

# ------------------------------------------------------------------------------
# Perform: Create Next Snapshot Version
# ------------------------------------------------------------------------------

log_info "Preparing next snapshot version."

nextVersion="$(tail --lines=1 <<< "$(pnpm version "prerelease" --preid "rc" --no-git-tag-version || throw_error "Failed to create next snapshot version.")")"
declare -r nextVersion

git commit --all --message "chore: next snapshot version: ${nextVersion}" >&2
nextHash="$(git rev-parse HEAD)"
declare -r nextHash

echo "Prepared next snapshot: ${nextVersion} (${nextHash})" >&2

if (( isSnapshotRelease == 0 )); then
  git tag --annotate --message "Release: ${releaseVersion}" "${releaseVersion}" "${releaseHash}" | log_info
fi

# ------------------------------------------------------------------------------
# Finish: Pushing Results or Report State
# ------------------------------------------------------------------------------

if (( push )); then
  git push | log_info

  if (( isSnapshotRelease == 0 )); then
    git push origin tag "${releaseVersion}" | log_info
    log_info "Tagged Release: ${releaseVersion} (${releaseHash})"
  fi
else
  log_info "Skipping to push changes."
  log_info "Stashed Commits:"
  git --no-pager log --oneline "${currentRef}..${nextHash}" | log_info

  if (( isSnapshotRelease == 0 )); then
    log_info "Tagged Release (not pushed): ${releaseVersion} (${releaseHash})"
  fi
fi

if (( json )); then
  log_info "Outputting JSON result."
  if (( isSnapshotRelease == 0 )); then
    diff="$(get_github_compare_url "${previousReleaseVersion}" "${releaseVersion}")"
  else
    # No tag available. Using the commit hash instead.
    diff="$(get_github_compare_url "${previousReleaseVersion}" "${releaseHash}")"
  fi
  declare -r diff

  declare jsonResult
  read -r -d '' jsonResult << end_json || true
{
  "project": "${projectName}",
  "artifact": {
    "name": "${artifactName}",
    "path": "${artifactPath}"
  },
  "current": {
    "version": "${currentVersion}",
    "hash": "${currentRef}",
    "isSnapshot": ${currentIsSnapshot}
  },
  "previous": {
    "version": "${previousReleaseVersion}",
    "hash": "${previousReleaseHash}"
  },
  "release": {
    "version": "${releaseVersion}",
    "hash": "${releaseHash}",
    "isSnapshot": ${isSnapshotRelease},
    "diff": "${diff}"
  },
  "next": {
    "version": "${nextVersion}",
    "hash": "${nextHash}"
  }
}
end_json
  if [ -n "${jsonPath}" ]; then
    echo "${jsonResult}" > "${jsonPath}"
    log_info "Wrote JSON result to: ${jsonPath}"
  else
    write_out "${jsonResult}"
  fi
fi
