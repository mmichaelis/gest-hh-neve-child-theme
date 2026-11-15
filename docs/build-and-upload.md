# Build and Upload

Use this guide to build a theme ZIP on your computer without starting the
GitHub release workflow.

## Before you start

You need Node.js 26 and PNPM 12. Use a macOS or Linux shell. On Windows, use
WSL. The packaging command uses a project dependency, so you do not need to
install `zip` or `unzip`.

This procedure uploads to the live WordPress site. For local layout checks, use
the separate [local WordPress test site guide](./local-wordpress.md). The local
copy is not a public staging site and does not provide an automated rollback.
Static checks do not test the rendered site. Before a live upload, know how to
restore a backup through your WordPress host.

## Build the theme ZIP

Run these commands from the repository root:

```bash
pnpm install --frozen-lockfile
pnpm run verify
pnpm run package
```

The package command replaces `build/gest-hh-neve-child`. It copies the theme
files from `src/`, writes the WordPress theme version from `package.json` into
the built `style.css`, and creates the ZIP.

The ZIP is `build/gest-hh-neve-child.zip`. Before writing it, the command
checks that the archive has one top-level `gest-hh-neve-child/` folder and
contains `style.css` and `functions.php`.

To keep an existing `build/` folder unchanged, pass a different output folder:

```bash
pnpm run package -- /tmp/gest-hh-neve-output
```

This creates `/tmp/gest-hh-neve-output/gest-hh-neve-child.zip`.

If `pnpm run verify` reports that a tool is unavailable, that check was
skipped. Install the missing tool and run verification again when you need all
checks.

## Upload the ZIP

1. Sign in to the WordPress admin area for the live site.
2. Open **Appearance → Themes → Add New Theme → Upload Theme**. The labels may
   differ if WordPress uses another language.
3. Choose `build/gest-hh-neve-child.zip`, then select **Install Now**.
4. If WordPress asks to replace the installed theme, confirm the replacement.
5. After installation, activate the theme if WordPress asks you to do so.
6. Open the public site and check the pages changed by the update.

Keep the previous theme ZIP or use your host's backup process if you need to
restore the site. This project does not automate rollback.
