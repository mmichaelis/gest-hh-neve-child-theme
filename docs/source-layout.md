# Theme Source Layout

The `src/` folder contains the files copied into the built WordPress theme.
The folder names show which part of the site owns each group of styles.

## Main files

- `src/style.css` imports the CSS modules. Import order affects which rule wins
  when two rules match the same element.
- `src/functions.php` loads the child theme stylesheet after Neve's stylesheet.
- `src/screenshot.png` is the theme preview image.
- `wordpress-theme-meta.json` holds theme metadata. The build adds it and the
  package version to the built `style.css`.

## CSS modules

The current import order in `src/style.css` is:

1. `gest/` — GEST colors, fonts, sizes, and site-specific rules.
2. `cookie-notice/` — cookie notice plugin rules.
3. `custom-facebook-feed/` — Custom Facebook Feed plugin rules.
4. `enhanced-tooltipglossary/` — CM Tooltip Glossary plugin rules.
5. `general/` — shared rules that do not belong to one module.
6. `gtranslate/` — GTranslate plugin rules.
7. `neve/` — Neve variables, overrides, and responsive or print rules.
8. `the-events-calendar/` — Events Calendar plugin rules.
9. `uag/` — UAG block plugin rules.
10. `wordpress/` — WordPress core and block styles.

Keep the existing order unless a change needs a different cascade.

## Files inside a module

Many modules use a `main.css` file to import smaller CSS files. Depending on
the module, these files may group colors, fonts, sizes, direct overrides, or
responsive and print rules. This is a pattern, not a rule: not every module has
every group.

For example, `neve/main.css` imports color and font settings, then direct
overrides, then media rules. `gest/main.css` imports the site's colors, fonts,
sizes, custom styles, and media rules.

## Changing plugin styles

When a plugin is removed from the site:

1. Confirm its WordPress plugin name and slug. The local folder name may use
   the plugin slug rather than its display name.
2. Search `src/` for the slug and for selectors used only by that plugin.
3. Check that the rules are not shared with Neve, WordPress, or another plugin.
4. If the styles are no longer needed, remove that module and its import from
   `src/style.css`.
5. Run `pnpm run verify` and build the theme again.

Do not remove `general/`, `gest/`, `neve/`, or `wordpress/` as part of removing
a plugin. These folders hold shared or theme-level rules.
