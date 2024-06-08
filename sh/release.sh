#!/usr/bin/env bash

set -o errexit   # abort on nonzero exit status
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

# Respect GitHub Actions debug mode.
declare -ir MODE_DEBUG=${RUNNER_DEBUG:-0}

# Detect if running in GitHub CI Environment.
MODE_CI=$( [[ "${CI:-false}" == "true" ]] && echo 1 || echo 0 )
declare -ir MODE_CI

CURRENT_HASH=$(git rev-parse HEAD)
declare -r CURRENT_HASH

if (( MODE_DEBUG )); then
  set -o xtrace
else
  set +o xtrace
fi

OPTIONS=$(getopt --options "dhpt:" --longoptions "dry-run,help,push,type:" --name "${BASH_ARGV0}" -- "$@" || exit 1)
declare -r OPTIONS

declare dryRun=0
declare help=0
declare type="unset"
declare push=0

eval set -- "${OPTIONS}"
while true; do
  if (( MODE_DEBUG )); then
    echo "Processing Argument: ${1:-EOA}" >&2
  fi
  case "${1:-EOA}" in
    -d | --dry-run)
      dryRun=1
      ;;
    -h | --help)
      help=1
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
      echo "Internal error! Unhandled valid option: '${1}'." >&2
      exit 1
      ;;
  esac
  shift
done

if (( help )); then
  echo "Usage: ${BASH_ARGV0} [OPTIONS]"
  echo "Options:"
  echo "  -d, --dry-run  Dry run mode."
  echo "  -h, --help     Display this help message."
  echo "  -p, --push     Push changes."
  echo "  -t, --type     Release type: snapshot (alias for prerelease), patch, minor, or major."
  exit 0
fi

declare -i onlySnapshot=0

case "${type}" in
  snapshot | prerelease)
    echo "Releasing a snapshot version." >&2
    type="prerelease"
    onlySnapshot=1
    ;;
  patch | minor | major)
    ;;
  unset)
    echo "Required argument --type is missing." >&2
    exit 1
    ;;
  *)
    echo "Invalid release type: '${type}'." >&2
    exit 1
    ;;
esac

declare releaseVersion=""
declare releaseHash=""
declare snapshotVersion=""
declare snapshotHash=""

if [ -z "$(git status --untracked-files=no --porcelain)" ]; then
  echo "Working directory clean." >&2
else
  echo "Working directory is dirty. Aborting." >&2
  git status --untracked-files=no >&2
  exit 1
fi

declare pnpmVersionOutput=""
declare artifactName=""

if (( ! onlySnapshot )); then
  echo "Releasing a ${type} version." >&2
  pnpmVersionOutput="$(pnpm version "${type}" --no-git-tag-version || exit 1)"
  releaseVersion="$(tail -n 1 <<< "${pnpmVersionOutput}")"
  git commit --all --message "chore: release ${type}: ${releaseVersion}" >&2
  releaseHash="$(git rev-parse HEAD)"
  echo "Released a ${type} version: ${releaseVersion} (${releaseHash})" >&2
  # Zip Build Results
  artifactName="$(pnpm --silent about name)-${releaseVersion}.zip"
  (cd build >&2 && zip --recurse-paths -9 "../${artifactName}" . >&2)
  echo "Created Release Artifact: ${artifactName}" >&2
fi

echo "Preparing next snapshot version." >&2
pnpmVersionOutput="$(pnpm version "prerelease" --no-git-tag-version --preid "rc" || exit 1)"
snapshotVersion="$(tail -n 1 <<< "${pnpmVersionOutput}")"
git commit --all --message "chore: next snapshot version: ${snapshotVersion}" >&2
snapshotHash="$(git rev-parse HEAD)"
echo "Prepared next snapshot: ${snapshotVersion} (${snapshotHash})" >&2

if (( dryRun )); then
  NEW_HASH=$(git rev-parse HEAD)
  declare -r NEW_HASH
  echo "Dry run mode enabled. Skipping to push results." >&2
  echo "Stashed Commits:" >&2
  git --no-pager log --oneline "${CURRENT_HASH}..${NEW_HASH}" >&2
  git reset --hard "${CURRENT_HASH}" >&2
  exit 0
fi

previousVersion="$(git describe --all --abbrev=0 --tags)"
declare -r previousVersion

git tag --annotate --message "Release: ${releaseVersion}" "${releaseVersion}" "${releaseHash}" >&2

if (( push )); then
  git push --follow-tags >&2
fi


if (( MODE_CI )); then
  ## Output the release information.
  printf '{"previousVersion":"%s","releaseVersion":"%s","snapshotVersion":"%s","artifactName":"%s"}\n' "${previousVersion}" "${releaseVersion}" "${snapshotVersion}" "${artifactName}"
fi
