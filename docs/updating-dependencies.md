# Updating Dependencies

Make dependency updates on a feature branch. Review the changed manifests and
lockfiles, then run `pnpm run verify`.

## PNPM packages

Update packages within their declared version ranges:

```bash
pnpm update
```

To include newer versions outside the current ranges, use:

```bash
pnpm update --latest
```

The second command can install breaking major versions. Review changes to
`package.json` and `pnpm-lock.yaml` before committing them.

## GitHub Actions

Update workflow action versions with:

```bash
pnpm run update-actions
```

This script checks GitHub for the latest release of each action and updates
the workflow to its latest major version tag. Review every change and run
`pnpm run verify` to check the workflow files.

The actionlint installer version is pinned separately in
`sh/install-actionlint.sh`; this command does not update it.
