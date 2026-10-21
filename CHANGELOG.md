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
- `fonts` unit: every KDE font role from the style (`font_size`, small
  fonts 2pt less); empty font names restore KDE's defaults. Missing
  families are reported as ingredients.
- `kome deps`: the install command for what a preset is missing, for the
  package manager found (dnf, zypper, pacman, apt); never runs it.
- `cursor` unit: Catppuccin cursors for Mocha/Latte as an optional
  ingredient (missing → cursor untouched, notice, and a per-user install
  command from `kome deps`); Breeze presets use `breeze_cursors`.
- `icons` unit: Papirus for the Catppuccin presets with folders in the
  preset's accent, through a small derived theme in your home (Papirus
  itself is never modified, no root); Breeze presets use KDE's icons.
- `kome purge`: restores `original`, then deletes everything in the
  manifest plus kome's snapshots and state; keeps your own config.

### Fixed

- After an icon change, the panel showed the old icons until hovered:
  every icon group is now told to reload.
- `kome restore original` now also restores units added after the first
  apply (e.g. fonts, cursor): each apply completes `original` with units
  kome has never touched.
- awk always runs with `LC_ALL=C`, so decimals never come out as `0,5`
  on systems with a non-English locale.
