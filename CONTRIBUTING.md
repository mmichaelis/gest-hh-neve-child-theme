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

## Auto-Fixes

Run the available automatic fixes with:

```bash
pnpm run lint:fix
```

The command formats the TypeScript scripts and configuration files, applies
ESLint and Stylelint fixes, and applies Markdownlint fixes. Review the changes
and run `pnpm run lint` again afterward.
