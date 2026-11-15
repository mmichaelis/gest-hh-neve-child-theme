---
applyTo: "src/**"
---
# Theme Source Instructions

- `style.css` is the stylesheet entry point. Its import order affects the CSS
  cascade; preserve it unless the change needs a different order.
- Keep styles in the area that owns them: `gest/` for GEST branding and site
  rules, `neve/` for Neve, `wordpress/` for WordPress, `general/` for shared
  rules, and plugin-named folders for plugin rules.
- Prefer Neve's CSS variables and keep direct selector overrides small.
- Before removing a plugin's CSS, confirm the plugin is no longer used. Search
  for its slug and selectors, remove its import from `style.css`, and check for
  shared rules that must remain.
- Each module may group imports by colors, fonts, sizes, media, or overrides.
  Not every module uses every group.
