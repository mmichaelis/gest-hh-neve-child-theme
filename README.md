# gest-hh-neve-child-theme

WordPress theme for [gest-hamburg.de](https://gest-hamburg.de) based on
[Neve](https://themeisle.com/themes/neve/)
([Codeinwp/neve](https://github.com/Codeinwp/neve)).

## Release

### Release Types

This repository uses _semantic versioning_, thus, quoting from [semver.org](https://semver.org):

> Given a version number `MAJOR.MINOR.PATCH`, increment the:
>
> 1. `MAJOR` version when you make incompatible API changes,
> 2. `MINOR` version when you add functionality in a backward compatible manner
> 3. `PATCH` version when you make backward compatible bug fixes.
>
> Additional labels for pre-release and build metadata are available as
> extensions to the `MAJOR.MINOR.PATCH` format.

For a pre-release we use the synonym "snapshot". Such a snapshot release
has a label `rc`, so that the _Release Candidate_ for version `1.2.3` would be
`1.2.3-rc.4`, where `4` is the next snapshot increment version.

If in doubt, choose:

* `patch` for typical releases to be used on the website.
* `snapshot` for releases to be used for testing purposes.

### Via GitHub Actions

1. Go to [Actions](https://github.com/mmichaelis/gest-hh-neve-child-theme/actions).
2. Select the [Release Workflow](https://github.com/mmichaelis/gest-hh-neve-child-theme/actions/workflows/release.yml).
3. Click on "Run workflow".
4. Select a release type (see above).
5. Click on "Run workflow".
6. Wait for the release to complete.
7. Find the release artifact `gest-hh-neve-child.zip` in the
   [Releases](https://github.com/mmichaelis/gest-hh-neve-child-theme/releases)
   section.

This artifact can be downloaded as is and uploaded to the WordPress site.

### Manually

Assume, you have no tooling, no Linux at hand, there is always a completely
manual way to create a ZIP suitable for uploading it to the WordPress site.

1. Copy the files located in `src/` to a new directory named
   `gest-hh-neve-child`.

2. Add required theme metadata to `style.css` in the header section. Best,
   compare it to previous versions and just increase the version number.
   Here is a sample, that may be used:

   ```css
   /*
   Theme Name:  GEST (Neve)
   Theme URI:   https://github.com/mmichaelis/gest-hh-neve-child-theme
   Template:    neve
   Author:      GEST Hamburg
   Author URI:  https://gest-hamburg.de/
   Description: Child theme for the Neve providing adaptations for the website gest-hamburg.de.
   License:     GNU General Public License v3 or later
   License URI: https://www.gnu.org/licenses/gpl-3.0
   Text Domain: neve
   Tags:        blog,custom-logo,e-commerce,rtl-language-support,post-formats,grid-layout,one-column,two-columns,custom-background,custom-colors,custom-header,custom-menu,featured-image-header,featured-images,flexible-header,full-width-template,sticky-post,theme-options,threaded-comments,translation-ready,accessibility-ready,hide-blocks,block-styles
   Version:     1.4.1
   */
   ```

3. Create a ZIP archive of the directory `gest-hh-neve-child` and name it
   `gest-hh-neve-child.zip`.

## Upload

1. Go to the WordPress site [gest-hamburg.de](https://gest-hamburg.de/).
2. Log in as administrator.
3. Go to the admin dashboard.
4. Go to "Design" -> "Themes".
5. Click on "Add New" (de: "Neues Theme hinzufügen").
6. Click on "Upload Theme" (de: "Theme hochladen").
7. Select the ZIP archive `gest-hh-neve-child.zip`.
8. Click on "Install Now" (de: "Jetzt installieren").
9. Confirm to override the previous version.
10. Wait for the installation to complete.
11. Click on "Activate" (de: "Aktivieren").
12. Done.
