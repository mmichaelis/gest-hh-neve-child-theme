# GitHub Release Process

Use this process for a versioned release. For a build that does not change
versions or Git history, use the [build and upload guide](./build-and-upload.md)
instead.

## Before a release

Merge the changes into `main`. Confirm that the latest verification workflow
passed. The release workflow does not run `pnpm run verify` itself.

## Start the release

1. Open the repository's **Actions** page.
2. Select **Release (Main)**, then choose **Run workflow**.
3. Select the `main` branch.
4. Choose a release type:
   - `snapshot` creates a test build without a GitHub Release.
   - `patch` is for backward-compatible fixes.
   - `minor` is for backward-compatible features.
   - `major` is for incompatible changes.
5. Start the workflow and wait for it to finish.

The workflow updates versions, creates commits, builds the theme ZIP, and
pushes the release changes. A stable release also creates a Git tag and a
GitHub Release. Do not start it as a way to make an ad hoc ZIP.

## Download the theme

For a stable release, download `gest-hh-neve-child.zip` from the GitHub Release.
That is the theme ZIP to upload to WordPress.

For a snapshot, download the `gest-hh-neve-child` artifact from the Actions run.
GitHub wraps uploaded artifacts in a download ZIP. The theme ZIP is inside
that downloaded file.
