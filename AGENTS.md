# Repository Instructions

- Check the current code, configuration, and workflows before describing or
  changing how the project works.
- Read the guide for the area you change. `docs/AGENTS.md` covers documentation,
  and `.github/instructions/theme-source.instructions.md` covers theme source.
- Keep changes focused. Do not assume that staging, WordPress integration tests,
  or automated rollback are available.
- Do not commit generated files from `build/`.
- Run `pnpm run verify` before finishing code or documentation changes. Report
  any checks that were skipped because a tool was not installed.
- Do not run `sh/release.sh` or the GitHub release workflow unless asked to
  create a release. They change versions and Git history, and can push commits
  and tags.
