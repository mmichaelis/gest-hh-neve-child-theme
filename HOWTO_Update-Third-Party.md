# Update Third-Party Dependencies

This document describes how to update third-party dependencies in the project.

## Updating NodeJS Dependencies

The project uses NodeJS for development purposes. The dependencies are managed
via `pnpm`.

### General Advice

When doing updates, always commit the changes to the `package.json` and
`pnpm-lock.yaml` file in extra commits. This makes it easier to track changes
and to resolve conflicts from other branches if necessary.

### Defensive Update

To update the dependencies, execute the following command:

```bash
pnpm update
```

This command updates all dependencies to the latest version that is compatible
with the current configuration. It is a good idea to run this command regularly
to keep the dependencies up-to-date.

### Latest Version Update

To update all dependencies to their  latest version, execute the following
command:

```bash
pnpm update --latest
```

This command updates all dependencies to the latest version available. It is
recommended to run this command only if you are prepared to deal with potential
breaking changes.

## Update GitHub Actions

The project uses GitHub Actions for continuous integration. The configuration
is stored in `.github/workflows/` and is written in YAML.

### General Advice

When doing updates, always commit the changes to the workflow files in extra
commits. This makes it easier to track changes and to resolve conflicts from
other branches if necessary.

### Update Actions to Latest Versions

To update the actions to the latest versions, execute the following command:

```bash
pnpm update-actions
```
