# Build and Upload

Use this guide to build a theme ZIP on your computer without starting the
GitHub release workflow.

## Before you start

You need Node.js 26, PNPM 12, and the `zip` and `unzip` commands. Use a macOS
or Linux shell. On Windows, use WSL.

On Ubuntu or WSL, install the archive tools if they are missing:

```bash
sudo apt update
sudo apt install zip unzip
```

This procedure uploads to the live WordPress site. The project does not have a
supported staging site or a documented, repeatable local WordPress setup. An
earlier Docker copy was experimental and is not maintained by the project.
There is no automated rollback command. Static checks do not test the rendered
site. Before an upload, know how to restore a backup through your WordPress
host.

## Build the theme ZIP

Run these commands from the repository root:

```bash
pnpm install --frozen-lockfile
pnpm run verify
pnpm run build
rm -f build/gest-hh-neve-child.zip
(cd build && zip -qr gest-hh-neve-child.zip gest-hh-neve-child)
unzip -l build/gest-hh-neve-child.zip
```

The build command replaces `build/gest-hh-neve-child`. It copies the theme
files from `src/` and writes the WordPress theme version from `package.json`
into the built `style.css`. It does not create a ZIP, so the commands above
create one separately.

The ZIP is `build/gest-hh-neve-child.zip`. Check the `unzip -l` output. The
archive must contain one top-level `gest-hh-neve-child/` folder with files such
as `style.css` and `functions.php`. It must not contain a `build/` folder at the
top level.

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
