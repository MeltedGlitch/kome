# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Repository skeleton: dispatcher (`kome --help`, `kome --version`),
  shared helpers, Makefile (per-user install by default), CI, licence.
- INI reader for kome's own files (`lib/kome/ini.awk`, `ini_get`,
  `ini_dump`): strict, no inline comments, `FILE:LINE` errors.
- Colour engine (`lib/kome/color.awk`): validate, `r,g,b`, mix,
  lighten, darken, WCAG luminance and contrast.
- README redesign (English and Spanish): banner, preset cards drawn in
  their real palettes, badges, roadmap, FAQ, contributing guide.
- Template placeholder syntax fixed in the design (`{{role:format}}`,
  `{{mix(a,b,t)}}`, …).
- Template engine (`lib/kome/template.awk`, `template_fill`,
  `template_render`): `{{name}}`, `:hex`/`:rgb`, `mix`/`lighten`/`darken`,
  `FILE:LINE` errors, atomic writes.
- Catppuccin Mocha and Latte palettes, the `soft` style and the `mocha`
  and `latte` presets.
- Preset resolution (`lib/kome/preset.sh`): user files override shipped
  ones; palettes are validated (all 27 roles, real colours).
- `kome list`.
- `colors` unit: generates a KDE colour scheme from the palette (or applies
  a shipped KDE scheme via `color_scheme=`), alternating `Kome-<preset>-A/B`
  because Plasma ignores re-applying the active scheme; `restore` verb.
- `breeze` and `breeze-dark` presets: KDE's shipped schemes, Noto Sans and
  Hack, plus approximate Breeze palettes for integrations.
- `kome apply` (`-n`, `-v`, `--partial`, preset from `kome.conf`) and
  `kome restore original|previous`: snapshots of every unit before each
  apply, a failed apply never overwrites `previous`, one kome at a time.
- Unit metadata (`unit.ini`): opt-in units, and notices for apps that need
  a restart, a re-login, or an optional ingredient (e.g. Klassy).

### Fixed

- awk always runs with `LC_ALL=C`, so decimals never come out as `0,5`
  on systems with a non-English locale.
