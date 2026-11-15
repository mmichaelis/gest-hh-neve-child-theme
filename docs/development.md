# Development

## Supported environment

Use a macOS or Linux shell. On Windows, use WSL with a Linux distribution such
as Ubuntu. Run the commands in this guide from the repository root unless a
step says otherwise.

The project requires Node.js 26 and PNPM 12. The repository pins PNPM 12.21.0
in `package.json`.

Check the installed versions:

```bash
node --version
pnpm --version
```

Install the exact dependency versions from the lockfile:

```bash
pnpm install --frozen-lockfile
```

## Run checks

Run the complete set of available checks:

```bash
pnpm run verify
```

This runs ESLint, TypeScript, Prettier, Markdownlint, Stylelint, actionlint, and
ShellCheck. If actionlint or ShellCheck is missing, the verifier warns and skips
that check. Other checks still run.

For the PNPM-managed checks only, run:

```bash
pnpm run lint
```

Apply available automatic fixes with:

```bash
pnpm run lint:fix
```

Review the changed files, then run `pnpm run verify` again.

To build the theme and create a ZIP locally, run:

```bash
pnpm run package
```

See the [build and upload guide](./build-and-upload.md) for the upload steps
and for using a separate output folder.

### Optional system tools

Install ShellCheck with your system package manager. On Ubuntu or Debian:

```bash
sudo apt install shellcheck
```

On macOS with Homebrew:

```bash
brew install shellcheck
```

The actionlint installer supports Linux and requires an authenticated GitHub
CLI:

```bash
gh auth login
./sh/install-actionlint.sh
```

It installs actionlint to `$HOME/.local/bin`. On macOS, install actionlint
using the [official installation guide](https://github.com/rhysd/actionlint/blob/main/docs/install.md).

## Checks and limits

The verification workflow runs on pull requests and pushes to `main`. The
GitHub release workflow does not run these checks itself, so confirm the latest
`main` verification passed before creating a release.

There is no test script, PHP lint check, WordPress integration test, or visual
regression test in this repository. Static checks do not show how a page will
look in WordPress.
