# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `decoration` unit: window corners and title bar buttons from the style,
  through Klassy (optional: without it windows keep their frame); the
  Breeze presets go back to KDE's own decoration.
- Seven presets: Tokyo Night, Rosé Pine, Rosé Pine Dawn, Nord, Everforest,
  Gruvbox Material and Kanagawa.
- `kome validate`: WCAG contrast check of each preset's palette.
- KDE accent colour set to the palette's accent; a softer disabled effect
  for light looks.
- Units `plasmastyle` (Plasma style: Klassy's or Breeze), `widgets` (widget
  style inside apps) and `effects` (blur, animation speed).
- `panel` unit (opt-in): `bar`, `dock` and `topbar` layouts on every
  screen; `kome restore` brings back the user's own panels exactly.
- Integrations `btop` and `vesktop`: a *kome* theme the user chooses once
  in the app.
- Mixing looks: `kome apply --palette P --style S`, `kome list palettes`,
  `kome list styles`.
- `kome preview`: a screenshot of the desktop with each preset, then back to
  the user's desktop.
- `kome doctor` detects Plasma's day/night theme switching (and turns it off
  with `--fix`) and advises on blurry X11 apps with fractional scaling.

### Fixed

- Window buttons set to circles showed only bare icons: the circles are now
  always visible (icons appear on hover), from the first apply on.
- `kome restore original` can now put back settings a unit started owning
  in a newer kome version.
- `kome restore` now brings back the palette and style a restored look was
  mixed with.
- With Klassy's Plasma style the panel kept Klassy's fixed colours: kome
  now uses a derived style with Klassy's graphics and the look's colours.
- `make install` left removed or renamed files behind (an old unit ran
  twice); kome doctor and kome list output is aligned and shorter.

## [0.1.0] - 2026-10-22

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
- `kome status` (`-v`): the active preset and, per unit, whether it is as
  applied, changed by hand (exit 1) or skipped.
- `kome doctor` (`--info`, `--fix`): what each unit can do here and why
  not; detects Plasma's accent-from-wallpaper; system facts.
- `kitty` integration: terminal colours from the palette in
  `kome-theme.conf`, live reload; `kome doctor --fix` adds the one
  `include` line to `kitty.conf`, and `kome purge` takes it out again.
- Template function `by_mode(dark,light)`.
- `kome doctor` recommends apps kome can theme that are not installed
  (e.g. kitty), with the install command.
- Tab completion for bash, zsh and fish (commands, options, presets —
  your own included), and `kome --commands`.
- `ghostty` integration: terminal colours from the palette, live reload,
  one `config-file` line added by `kome doctor --fix`, removed by purge.
- After an icon change, kome refreshes Plasma's panel (with or without
  systemd), which otherwise keeps old icons until hovered;
  `RefreshPanel=off` in kome.conf turns it off.
- `rendering` unit (opt-in, `rendering=on` in kome.conf): greyscale
  antialiasing and slight hinting for every app (fontconfig), FreeType stem
  darkening through a Plasma login script, and the same for KDE apps.
- `wallpaper` unit (opt-in, `wallpaper=` in the preset): desktop and lock
  screen; restoring brings back each screen's own wallpaper or slideshow.
- Man pages: `kome(1)` and `kome.conf(5)`.

### Fixed

- With `icon_accent=blue`, Papirus's bluegrey folders leaked into the
  generated icon theme.
- "Restart your apps" / "log out" notices appeared even when nothing had
  changed; `kome restore` now gives them when it does change something.
- `apply`, `deps` and `doctor` now pick the default preset the same way:
  `Preset=` in kome.conf, else the active one.
- `kome restore` no longer touches parts of the desktop kome never changed.
- `kome restore original` lost changes you made by hand to a unit kome had
  not applied yet (e.g. one turned on later): such units are now saved
  fresh until kome first applies them.
- Applying the same look twice no longer regenerates colours or icons.
- Tray icons looked grey or white in kome's icon themes: the generated
  theme now keeps the base theme's KDE settings, above all
  `FollowsColorScheme`, so Plasma recolours them again.
- Light looks showed some icons white on white: icons the icon pack lacks
  now fall back to Breeze in the look's own mode.
- Tests no longer depend on programs installed on the machine running them.
- GTK apps kept the old icons and fonts: kome now writes KDE settings with
  `kwriteconfig6 --notify`, so Plasma syncs them to GTK.
- After an icon change, the panel showed the old icons until hovered:
  every icon group is now told to reload.
- `kome restore original` now also restores units added after the first
  apply (e.g. fonts, cursor): each apply completes `original` with units
  kome has never touched.
- awk always runs with `LC_ALL=C`, so decimals never come out as `0,5`
  on systems with a non-English locale.
