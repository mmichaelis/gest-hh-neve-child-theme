# Contributing

## Development Setup

Install Node.js 26 and PNPM 12, then install the project dependencies:

```bash
pnpm install
```

## Static Checks

Run the project checks before opening a pull request:

```bash
pnpm run lint
```

This runs ESLint, TypeScript checking, Prettier formatting checks,
Markdownlint, and Stylelint.

Run the full workspace verification, including ShellCheck and actionlint, with:

```bash
pnpm run verify
```

Install [ShellCheck](https://github.com/koalaman/shellcheck#installing) with
your operating system's package manager. On Debian or Ubuntu, run
`sudo apt install shellcheck`. Install
[actionlint](https://github.com/rhysd/actionlint/blob/main/docs/install.md)
from its official prebuilt release. If an external tool is unavailable, the
verifier warns and skips that check; failures from available tools still make
verification fail after the remaining checks run. The pull-request workflow
uses ShellCheck on Ubuntu and downloads actionlint v1.7.12 with provenance
verification.

## Auto-Fixes

Run the available automatic fixes with:

```bash
pnpm run lint:fix
```

The command formats the TypeScript scripts and configuration files, applies
ESLint and Stylelint fixes, and applies Markdownlint fixes. Review the changes
and run `pnpm run lint` again afterward.
