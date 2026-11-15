# Local WordPress Test Site

Use this guide to restore a private copy of the WordPress site for theme and
layout checks. The local copy uses the supplied database and home backups. It
does not connect to or change the live site.

The local copy contains production content and may contain personal data or
secrets. Keep it on this computer, and do not send its database, credentials, or
error logs to other people.

## What You Need

Run the commands in this guide from the repository root. On Windows, open the
repository in WSL and use a Linux shell.

You need:

- Docker Desktop, running with WSL integration enabled.
- Docker Compose, included with current Docker Desktop installations.
- Node.js 26 and PNPM 12 to build the child theme.
- Python 3.10 or later, `curl`, OpenSSL, and GNU coreutils in WSL.
- The database backup and home backup.

Check the installed tools:

```bash
docker --version
docker compose version
node --version
pnpm --version
python3 --version
curl --version
openssl version
```

If a command is missing, install that tool in WSL or update Docker Desktop. The
installer also checks its prerequisites and names any missing tool. If project
packages are not installed, run:

```bash
pnpm install --frozen-lockfile
```

The installer builds the child theme. Generated files stay in the ignored
`build/` directory.

## First Install

Make sure Docker Desktop is running. Then pass the two backup paths to the
installer. These example paths use the backups in the ignored planning folder:

```bash
backup_folder="my-planning/2026-11-15-local-deployment/gest-backup"
database_backup="mysql_db_backup_20261115212956.tar"
home_backup="home_20261115212719.tar.gz"

sh/install-wordpress.sh \
  --database-backup "${backup_folder}/${database_backup}" \
  --home-backup "${backup_folder}/${home_backup}"
```

If you keep the backups elsewhere, replace these paths with their actual
locations. The installer reads the WordPress version from the home backup. It
starts with PHP 8.3, MariaDB 10.11.4, and port 8080. You can override the
WordPress version, PHP version, or port:

```bash
sh/install-wordpress.sh \
  --database-backup /path/to/database-backup.tar \
  --home-backup /path/to/home-backup.tar.gz \
  --wordpress-version 7.1.4 \
  --php-version 8.3 \
  --port 8080
```

The installer checks the archives, pulls the required images, builds the child
theme, restores only the parent theme, plugins, and uploads, then imports the
database. It does not extract the full home archive or reuse its
`wp-config.php`. It will not overwrite existing local data unless you pass
`--reset`.

The site is available at [http://localhost:8080](http://localhost:8080). The
installer creates a local reviewer login and saves its password in
`.local-wordpress/credentials.txt`. Open that file on this computer to sign in
at `http://localhost:8080/wp-login.php`. Do not paste the password into a ticket
or commit it. The reviewer can read private pages but does not have WordPress
administrator access.

## Network and Email Limits

The WordPress and database containers use a Docker bridge with outbound
masquerading disabled. Only the local WordPress port is published; the database
port is not. No mail service or inbound mail port is provided. A local-only
WordPress plugin also makes `wp_mail()` return failure. Do not send test
messages.

The browser policy permits Google Fonts only from `fonts.googleapis.com` and
`fonts.gstatic.com`, because the child theme uses those fonts for its layout.
This request comes from the browser when a page uses the fonts. Google may
receive the computer's IP address. The policy does not allow other third-party
browser scripts, APIs, images, or frames. Fonts already cached by the archived
OMGF plugin may be served locally instead.

## Start and Stop

Containers do not start automatically after a computer restart. From the
repository root, start the site when you need it:

```bash
docker compose --env-file .local-wordpress/.env up -d
```

Open `http://localhost:8080` in a browser. To stop the containers while keeping
the database and restored files, run:

```bash
docker compose --env-file .local-wordpress/.env down
```

Run the start command again after a reboot. The normal stop command preserves
the database and site files.

## Change the PHP Version

Use the helper to select a different PHP version. For example:

```bash
sh/set-wordpress-php-version.sh 8.3
```

The helper checks and pulls the matching WordPress and WP-CLI images, then
recreates only the WordPress container. It does not reimport the database or
delete local files. Check plugin compatibility before selecting a PHP version
other than 8.3.

## View the Plugin Inventory

The installer saves plugin names, versions, and active states in
`.local-wordpress/plugins.txt`. You can also query WordPress from the repository
root:

```bash
docker compose --env-file .local-wordpress/.env run --rm --no-deps cli \
  --path=/var/www/html --skip-plugins --skip-themes \
  plugin list --fields=name,status,version --format=table
```

This inventory does not require an administrator login.

## Reset or Remove the Site

To discard the local copy and import the backups again, pass `--reset` to the
installer. This deletes this project's local database, restored files, and
credentials before starting a fresh restore. It does not delete the two input
archives:

```bash
backup_folder="my-planning/2026-11-15-local-deployment/gest-backup"
database_backup="mysql_db_backup_20261115212956.tar"
home_backup="home_20261115212719.tar.gz"

sh/install-wordpress.sh \
  --database-backup "${backup_folder}/${database_backup}" \
  --home-backup "${backup_folder}/${home_backup}" \
  --reset
```

To remove the local site completely, run:

```bash
sh/remove-wordpress.sh --delete-data
```

The script asks you to type `DELETE` before it removes this project's
containers, Docker volumes, restored files, and local credentials. To confirm
without a prompt, add `--yes`. The script leaves the supplied backups and the
generated theme build untouched.

## Local Files and Privacy

The ignored `.local-wordpress/` directory contains database credentials,
reviewer credentials, the restored site files, and private import error details
if an import fails. Do not add it to Git or share it. The restored database may
contain personal data, password hashes, and service credentials.

The database and WordPress core also live in project-specific Docker volumes.
Removing containers alone does not delete those volumes. Use the explicit
removal command when you want to erase the local copy.

## Troubleshooting

- **Docker is unavailable:** Start Docker Desktop and confirm that WSL
  integration is enabled for this Linux distribution.
- **A required tool is missing:** Install the tool named by the installer. Use
  Node.js 26, PNPM 12, and Python 3.10 or later.
- **The selected port is busy:** Choose another local port with `--port`, for
  example `--port 8081`, then open `http://localhost:8081`.
- **Image download fails:** Check the WordPress/PHP version and internet
  connection. The site containers themselves do not have general internet access
  after they start.
- **Database import fails:** The installer stores private details in
  `.local-wordpress/database-import.log`. Review it locally; it may contain data
  from the backup, so do not share it.
- **The page does not load:** Check container status and logs:

  ```bash
  docker compose --env-file .local-wordpress/.env ps
  docker compose --env-file .local-wordpress/.env \
    logs --tail=80 wordpress database
  ```

- **A font or plugin feature does not work:** The browser policy blocks
  third-party services other than Google Fonts. The containers cannot reach
  external APIs. This is intentional for the local copy.
- **You want to change the restored data:** Stop the site, then use `--reset` to
  import the backups again. This removes unsaved local changes.

This is a local test copy, not a public staging service, production backup
system, or automated rollback tool. It may not match the live site exactly.
