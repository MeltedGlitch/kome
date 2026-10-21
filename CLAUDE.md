# CLAUDE.md — `kome`

> **Status: v0.1 IN DEVELOPMENT.** The v0.1 design is frozen (2026-10-21).
> Build v0.1 as described here, one small step at a time. Design changes are
> still welcome, but go through this document first: update it, log the
> decision, then change the code.

---

## Current state (update at the end of every session)

**Last session: 2026-10-22.** Repo: `github.com/MeltedGlitch/kome` (private),
branch `main`, CI green, 200 bats tests passing (also under `gawk --posix`).

Done: dispatcher (+ `--commands`); `lib/kome/{common,preset,units,deps}.sh`
and `{ini,color,template,resolve}.awk`; presets `breeze`, `breeze-dark`,
`mocha`, `latte`; styles `soft`, `breeze`; units `colors`, `icons`,
`cursor`, `fonts` and integrations `kitty`, `ghostty` (each with
`unit.ini`); commands `list`, `apply`, `restore`, `deps`, `status`,
`doctor` (`--info`, `--fix`), `purge`; completions (bash/zsh/fish). Tests
run against a fake Plasma with a hermetic PATH (`tests/helpers.bash`).

Verified live by the owner: colours, fonts, icons (incl. the
FollowsColorScheme fix), GTK sync via `--notify`, automatic panel refresh
after icon changes (systemd path), idempotent re-apply (no refresh), purge.
Owner switched terminal to Ghostty (COPR); kitty uninstalled.

Owner's machine: Fedora 44, Plasma/KWin 6.7.5, Wayland, Intel + NVIDIA
RTX 4070, HDMI-A-1 2560x1440@143.91 and DP-1 2560x1440@144 (he said one is
165 Hz), both scale 1.25.

Open threads:
- KDE Connect's tray phone looks very faint on Latte: likely its
  "disconnected" state drawn with the colour scheme's Disabled effect,
  which kome copied from Breeze Dark. Owner was asked whether his phone was
  connected; proposal: a softer Disabled effect for light looks.
- `kome doctor`: detect Plasma's automatic light/dark switching (key to
  verify).

**Next:** `rendering` (opt-in), `wallpaper` (opt-in), man pages.

Ask before reading or changing anything outside the repo on the owner's
machine.

---

## 0. Working agreement (read first)

- **Language.** The owner (Antonio) writes in Spanish. Talk to him in Spanish.
  Everything that goes into the repo — code, comments, CLI messages, `--help`,
  man pages, commit messages, this file — is in **English**. The README exists in
  two versions: `README.md` (English) and `README.es.md` (Spanish).
- **Work autonomously, in small verified steps.** Chain several implementation
  steps without asking (write → test → commit → push), as long as each one is
  small, tested and committed on its own. Stop and ask only for: anything
  that changes the owner's live desktop or config (running a unit's `apply`,
  `plasma-apply-*`, `kwriteconfig6` on real files), design decisions not
  covered here, or anything outward-facing beyond pushing to the private repo.
  When the owner must run something himself, give only that next step.
- **Short and direct.** No filler. Briefly explain *why* before giving commands to
  copy and paste.
- **Keep this file alive.** When a decision is made, update the relevant section
  and add a dated entry to the Decision log (§17). When something is still open,
  put it in Open questions (§16). Never silently drop an idea the owner proposed:
  move it to Deferred (§15) with a reason.
- **Push back.** If a proposal breaks the principles in §2, say so plainly and
  propose the simpler alternative.

---

## 1. Intent

**kome** (米, Japanese for uncooked rice — a nod to "ricing") is a desktop rice
tool for **KDE Plasma 6** that changes the **entire look** of the
desktop in one click or one command, coherently and beautifully: colours, fonts
of the whole system, icons, cursor, window decorations and their shape, widget
style, the panel/taskbar, the terminal, and GTK apps — all unified.

Aesthetic: soft, pastel, modern; Catppuccin / Tokyo Night / Rosé Pine territory.

It ships as a small, well-made UNIX command-line tool, published on GitHub,
reproducible on any machine running Plasma 6 (first targets: the owner's two
Fedora KDE laptops), with the polish a UNIX/GNU enthusiast expects: man pages,
completions, `--help`, dry-run, sane exit codes, XDG paths, `make install`.

It is also a learning project: clean design matters as much as the result.

**Audience.** A public project, aimed first at the owner's friends but open to
anyone. It must be as seamless for a stranger with a fresh Plasma install as for
the owner — so nothing may depend on the owner's `dotfiles` to work well.

---

## 2. Guiding principles

These are requirements, not suggestions. Every design decision is checked
against them.

1. **UNIX philosophy.** Each program does one thing well. Small executables with
   near-atomic responsibilities, composed by a thin dispatcher. Text in, text
   out. Data to stdout, diagnostics to stderr. Silence on success unless `-v`.
2. **KISS.** The simplest thing that works. Shell + tools Plasma already ships.
   Plain INI files. No daemons, no databases, no frameworks.
3. **YAGNI.** Nothing is built "in case". Features enter only when needed now;
   everything else waits in the roadmap (§14) or in Deferred (§15).
4. **Component-based.** The core knows nothing about specific themes or apps.
   All appearance work is done by **units** (§6) that share one identical
   contract. Adding support for something = adding one unit directory, no core
   changes.
5. **Minimal dependencies.** Hard deps: only what Plasma 6 itself provides plus
   POSIX tools (sh, awk, sed, coreutils) and standard D-Bus tools
   (`dbus-send`/`busctl`). Everything else is optional and a missing optional
   dependency only disables the unit that needs it.
6. **Scope discipline.** `kome` changes appearance, at user level, nothing else
   (§3). It does not install packages, does not need root, does not manage
   monitors, does not sync files, does not schedule anything.
7. **Distro-agnostic.** Works on any Linux distro with Plasma 6. Distro-specific
   knowledge lives only in **data** used for human-facing output (`kome doctor`
   hints, `kome deps` package names), never in logic.
8. **Safe and reversible.** Idempotent (applying twice = applying once). An
   automatic snapshot before every apply. If an apply fails midway, kome stops
   and tells the user the exact `kome restore` command to go back (no automatic
   rollback: it would itself be a live re-apply that can fail). Never touches
   settings it does not own.
9. **Uniformity.** Same concepts, same names, same flags, same file format
   everywhere. If two things look alike, they should work alike. User files
   always override shipped files, the same way everywhere.
10. **Complementary and easy to remove.** `kome` never overrides or constrains
    other programs on the system or the user's own config. It only writes files
    it owns; where a user file must point to them, it adds at most one
    `include`-style line, once. Anything that would touch another program is
    asked first (`[y/N]`). Removing `kome` must leave the system exactly as it
    would be without it.
11. **Guided, never manual-dependent.** Every warning or error ends with the
    exact next command to run. A user should never need the man page; it is
    there for those who want it.

---

## 3. Scope

**In scope (user-level appearance):**
Plasma colour scheme, icon theme (+ folder accent colour), cursor, fonts and
font rendering, window decoration, widget (application) style, panel layout,
terminal colours/font, GTK theming, and — only if the user opts in — wallpaper.

**Out of scope (and where it goes instead):**

| Thing | Where it belongs |
|---|---|
| Installing packages, themes, fonts | The user's package manager (`kome deps` prints the command) / `dotfiles` |
| Anything needing root (SDDM login screen, Plymouth) | `dotfiles` repo or a separate tool |
| Monitor resolution, scaling, refresh rate | System Settings; `kome doctor` may *advise* only |
| Scheduling (e.g. light/dark by time of day) | A systemd user timer in `dotfiles` that *calls* `kome` |
| Syncing config between machines | Any dotfile manager (chezmoi, yadm, stow, git) |
| Shell configuration, aliases | `dotfiles` |
| Shipping wallpapers | Not done: the user's own wallpapers are kept |

**Non-goals:**

- A GUI theme editor.
- Supporting Plasma 5 or other desktops.
- **Replacing or generating KDE Global Themes (Look-and-Feel packages).** They
  are static (they cannot derive colours from a palette), and applying one
  resets the panel layout and other settings wholesale — against principle 10.
  `kome` works below that level, one setting family per unit.

---

## 4. Two repositories

1. **`kome`** — the tool. Generic, distro-agnostic, publishable. Knows nothing
   about the owner's machines.
2. **`dotfiles`** — the owner's personal setup, managed with a dotfile manager
   (chezmoi is the current favourite: templates per machine). Contains:
   `~/.config/kome/kome.conf`, personal presets, terminal/shell config, a Fedora
   installer script that installs packages + `kome`, per-machine templates
   (HP Victus, ThinkPad T480), and anything root-level or scheduled.

For the owner, "one click on any PC" = `dotfiles` bootstrap (e.g.
`chezmoi init --apply <user>`), which installs `kome` and runs
`kome apply <preset>`. For everyone else: install `kome`, then
`kome apply <preset>` and follow the hints.

---

## 5. Core concepts

| Concept | What it is | Contains |
|---|---|---|
| **Palette** | Colours only | Catppuccin's 26 roles + `accent`: `base mantle crust surface0 surface1 surface2 overlay0 overlay1 overlay2 text subtext0 subtext1 rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender accent`. Every palette defines all 27, as `#rrggbb` only. Other upstream palettes (Nord, Tokyo Night…) are mapped onto these roles |
| **Style** | Shape only | v0.1: UI font, monospace font and `font_size` (points, default 10; an empty font = KDE's default). Later (with `decoration`/`style`/`panel`): corner radius, window button shape, titlebar height, panel layout, opacity |
| **Preset** | A palette + a style + a few extras | Icon folder accent (a Papirus folder colour name: `violet`, `blue`, `indigo`…), cursor theme, light/dark flag, optional KDE `color_scheme`, optional wallpaper path |
| **Unit** | One appearance target | Implements the unit contract (§6) |
| **Snapshot** | Saved state of everything `kome` can touch | Used by `kome restore`. Only two exist: `original` and `previous` |
| **Ingredient** | Something a preset needs to exist on the system | A font, icon theme, cursor theme, decoration engine (e.g. Inter, Papirus, Klassy) |
| **Manifest** | List of every file and line kome has created | Used by `kome purge` |

Palettes and styles are separate files so they can be **mixed**: a preset can
take the palette of one look and the style of another. In v0.1 that is done by
writing a preset file; CLI flags for it come later (§14).

Data flow:

```
preset.ini ──► palette.ini ─┐
          └──► style.ini  ──┼──► kome apply ──► check all units (list missing ingredients)
kome.conf (global settings)─┘        │                │
                                     │                └──► snapshot `previous` ──► apply each unit in order
                                     └──► on failure: stop + hint `kome restore previous`
```

---

## 6. Units

### Contract

Every unit is a directory `libexec/kome/units/NN-name/` (run-parts style: `NN` sets the
order, e.g. `10-colors`, `20-icons`, `90-kitty`) containing an executable
`unit`, its templates, and its metadata. Units never call or depend on each
other; the only coupling is the order.

The executable has exactly these verbs:

```
unit check     # can this unit work here? (exit codes below), reason on stderr
unit apply     # apply the values it receives in the environment
unit current   # print what is currently set, as key=value lines
unit restore   # re-apply a state printed by `current`, read as key=value lines on stdin
```

`current` and `restore` are inverses: `unit current | unit restore` changes
nothing.

Optional 5th verb, **`fix`**: a unit whose `check` prints `fix:<what>` lines
(with exit 0) offers reversible fixes; `kome doctor --fix` runs `unit fix`,
which must record what it changes in the manifest. Used by `kitty` for its
one `include` line. Snapshots store `current`'s output per unit; `kome restore` feeds it
back to `restore`.

`check` exit codes (documented, the same for every unit):

| Code | Meaning | What kome does |
|---|---|---|
| 0 | Ready | Apply it |
| 1 | Target absent (integration's app not installed; may print `app:<name>` on stdout) | `apply` skips it silently (shown with `-v`); `doctor` shows it with the command to install the app |
| 2 | Ingredient missing (names printed on stdout) | List it, hint `kome deps`; skip only with `--partial` |
| 3 | Other problem (reason on stderr) | Report it with a hint; stop |
| 4 | Optional ingredient missing (names printed on stdout) | Skip this unit, apply the rest, and **always** tell the user what to install to get it (not only with `-v`), with a hint to `kome deps` |

Values are passed as environment variables with a `KOME_` prefix
(`KOME_ACCENT=#b4befe`, `KOME_FONT_UI=Inter`, `KOME_MODE=dark`, …).

Each unit declares its metadata in a sidecar **`unit.ini`** next to the
executable (read with the same INI reader, never executed). The name comes
from the directory (`10-colors` → `colors`); ingredients come from `check`.

```ini
[Unit]
Format=1
description=Plasma colour scheme          # for kome doctor and --help
kind=core                                 # core | integration
default=on                                # on | off (opt-in units)
takes_effect=live                         # live | restart | relogin | shell
min_plasma=6.0
gives=the colours of Plasma and KDE apps  # "install X to also theme <gives>"
```

`kome.conf` `[Units] <name>=on|off` overrides `default`. After an apply,
units with `takes_effect=restart|relogin` produce a notice saying what
needs a restart or a re-login. `takes_effect=shell` (icons) means Plasma's
shell does not repaint the change by itself (a known Plasma bug): when such
a unit's state really changed, `apply`, `restore` and `purge` end by
refreshing the panel — `systemctl --user restart plasma-plasmashell` when
Plasma runs under systemd, else `plasmashell --replace`, else (no Plasma
session) only a hint. `kome.conf` `[General] RefreshPanel=off` keeps only
the hint.

`kome doctor` is nothing more than running `check` on every unit.

`current` is not a nice-to-have: it powers snapshots and drift detection
(`kome status`), so every unit must report its state reliably.

Power users can run any unit directly by path; there is no special subcommand.

### Core units vs integrations

- **Core units** are `kome`'s own domain: the look of the desktop itself.
- **Integrations** (e.g. `kitty`) are support for third-party apps. They are
  optional by nature.

### Missing things

| What is missing | Example | Behaviour |
|---|---|---|
| The **target** of an integration | Kitty not installed | Unit is skipped silently (mentioned only with `-v`). Not an error: nothing to theme. |
| A required **ingredient** of the look | Inter, Papirus | Clearly listed before anything is applied, with a hint to `kome deps <preset>`. Nothing is applied unless the user passes `--partial`, which applies as much as possible. |
| An **optional ingredient** | Klassy (window decoration) | The unit is skipped and everything else is applied; the windows keep their current frame. A visible notice always says what to install to get it (e.g. "install Klassy to theme window borders and buttons") and hints `kome deps <preset>`. |

### Catalogue (initial)

| Unit | Kind | Mechanism | Default | Live? |
|---|---|---|---|---|
| `colors` | core | generate `.colors` from template → `plasma-apply-colorscheme`; if the preset sets `color_scheme=` (e.g. `BreezeDark`), apply that installed KDE scheme instead, ungenerated | on | yes |
| `icons` | core | Papirus (only icon theme with complete coverage of KDE apps). Folder accent via a tiny **derived theme** generated in `$XDG_DATA_HOME/icons/` that inherits from Papirus and overrides only folder icons (no root, works with the distro package, Papirus untouched); `kwriteconfig6` | on | yes |
| `cursor` | core | `plasma-apply-cursortheme`. Catppuccin presets use the official Catppuccin cursors as an **optional ingredient** (rarely packaged): if missing, the cursor is left as is, with a notice | on | yes |
| `fonts` | core | `kwriteconfig6` for all font roles (general, fixed, small, toolbar, menu, window title), size from the style; an empty font name deletes the key so KDE's default applies (used by the Breeze presets) | on | mostly |
| `rendering` | core | user fontconfig file + `environment.d` (stem darkening), recommended values (§10) | **opt-in** | re-login |
| `gtk` | — | **Not a unit** (verified 2026-10-22): Plasma's kde-gtk-config already syncs colours (`colors.css`), cursor, icons and fonts to GTK whenever kome changes them through Plasma's tools or `kwriteconfig6 --notify`. `gtk.css` belongs to Plasma; kome never touches it. Flatpak theming: deferred | — | — |
| `wallpaper` | core | `plasma-apply-wallpaperimage` + lock screen config, only from a path the user gives in a preset. Never on by default: the user's wallpapers are kept | **opt-in** | yes |
| `kitty` | integration | generated theme file included from `kitty.conf`; reload all instances (SIGUSR1 / remote control) | on | yes |
| `decoration` (v0.2) | core | Klassy (**optional ingredient**: without it windows are left untouched, with a notice) via its config + KWin reconfigure over D-Bus (`dbus-send`/`busctl`) | on | yes |
| `style` (v0.2) | core | widget style (Klassy / Darkly / Breeze) via `kwriteconfig6` | on | new apps only |
| `panel` (v0.2) | core | Plasma desktop scripting (JS) via D-Bus `evaluateScript`; multi-monitor aware; destroys custom widgets | **opt-in** | yes |

Every write to KDE's config uses **`kwriteconfig6 --notify`**, so Plasma and
its GTK sync react as if the change came from System Settings (without it,
GTK apps kept old icons and fonts). Tests enforce it.

D-Bus calls use `dbus-send` or `busctl`, never `qdbus6` (its binary name
differs between distros, e.g. `qdbus-qt6` on Fedora).

Strict rule: a unit only changes the keys it owns.

**User files** (`kitty.conf`, …): a unit writes only its own file (e.g.
`kitty/kome-theme.conf`) and needs at most one `include`-style line in the
user's file, added once. Undo = delete kome's file (and that line). `apply`
never adds that line itself: it says the line is missing and points to
`kome doctor --fix`.

**Templates** follow the same override rule as everything else: a template in
`$XDG_CONFIG_HOME/kome/templates/<unit>/` replaces the shipped one. Shipped
templates are commented so power users can copy and tweak them — e.g. the
`rendering` template for custom fontconfig values.

---

## 7. Commands

Dispatcher: `kome <sub> [args]` executes `kome-<sub>` from `libexec/kome/` (git-style).
Each subcommand is its own executable and can be run directly.

**v0.1:**

| Command | Does exactly this |
|---|---|
| `kome apply [preset]` | Check all units and list missing ingredients → snapshot `previous` → apply each enabled unit in order. On failure: stop, report which unit failed, print `kome restore previous`, and mark the apply as failed; while that mark exists, the next apply does **not** overwrite `previous` (so the last good look is never lost). Without an argument uses `Preset=` from `kome.conf`. `-n` prints the plan (units and values) and changes nothing. `--partial` applies even if ingredients are missing |
| `kome list` | List available presets (user dir overrides system dir) |
| `kome doctor` | Run every unit's `check`; report what can / cannot be riced and why, with `hint:` lines. Also detects Plasma features that would silently undo kome's look (accent colour from wallpaper, automatic light/dark theme switching — to verify on Plasma 6.x) and offers to turn them off via `--fix` (`[y/N]`). Exit code reflects result |
| `kome doctor --info` | Also print the system facts relevant to ricing: Plasma/KWin/Qt versions, Wayland/X11, screens, scale, effective DPI, GPU, current font rendering |
| `kome doctor --fix` | Apply the fixes doctor found. Reversible fixes (tracked in the manifest, e.g. the one-time `include` line) are applied directly and reported. Fixes that touch anything beyond that (e.g. Flatpak overrides) ask first (`[y/N]`, details shown); without a TTY they are skipped with a hint. Never installs packages |
| `kome deps [preset]` | Print the missing ingredients of a preset as the exact install command for the user's package manager (dnf, apt, pacman, zypper…, detected at runtime). Ingredient → package name mapping lives in a data table. Never runs it |
| `kome status` | Show the active preset and any drift: settings changed by hand since the last apply (compares each unit's `current` with the preset). Units skipped by `--partial` or disabled are shown as *skipped*, not as drift. Reports only, never fixes |
| `kome restore original\|previous` | `original`: the whole look as it was before kome ever ran (colours, fonts, icons, cursor, decoration, style, panel…, whatever it was), taken once on the first apply and never overwritten; it covers **every** unit, including disabled and opt-in ones. `previous`: the look before the last apply |
| `kome purge` | Leave the system as if kome had never been used: restore `original`, then delete every file and line in the manifest, plus kome's state and snapshots. The user's own files in `$XDG_CONFIG_HOME/kome/` (kome.conf, own presets) are kept; purge prints their path in case the user wants to delete them |

There is **no** `kome default` command:

- Own previous look = `kome restore original`. kome does not care which theme
  that was.
- KDE factory look = `kome apply breeze` or `kome apply breeze-dark` (normal
  presets: Breeze / Breeze Dark, Noto Sans, standard panel).

One preset = one look = one mode. A light and a dark variant are always two
presets (`breeze` / `breeze-dark`, `latte` / `mocha`).

---

## 8. Files, paths and formats

All formats are **INI** (like KDE's own config). kome reads its own files with
a tiny POSIX awk reader (`lib/kome/ini.awk`): fast, testable in CI without
Plasma, and config is never executed as code. `kreadconfig6`/`kwriteconfig6`
are used only for KDE's own config files. Every data file carries `Format=1`
for future migrations.

| Path | Purpose |
|---|---|
| `$XDG_CONFIG_HOME/kome/kome.conf` | Global settings: preset used by a bare `kome apply`, units on/off |
| `$XDG_CONFIG_HOME/kome/{presets,palettes,styles,templates}/` | User files (override shipped ones) |
| `$PREFIX/share/kome/{presets,palettes,styles}/` (default `~/.local/share/kome`) | Shipped data |
| `$PREFIX/libexec/kome/units/` | Shipped units (internal executables, not for direct use) |
| `$XDG_STATE_HOME/kome/` | Active preset, manifest, log, lock file |
| `$XDG_DATA_HOME/kome/snapshots/` | Snapshots `original` and `previous` |

Sketch (field names not final):

```ini
# presets/mocha.ini
[Preset]
Format=1
name=Catppuccin Mocha
palette=catppuccin-mocha
style=soft
mode=dark
icon_accent=violet
# accent=#cba6f7                 (optional: preset keys override palette/style)
# wallpaper=/path/to/image.png   (only used if the wallpaper unit is on)
```

```ini
# palettes/catppuccin-mocha.ini
[Palette]
Format=1
base=#1e1e2e
text=#cdd6f4
accent=#b4befe
# … all roles
```

```ini
# styles/soft.ini
[Style]
Format=1
font_ui=Inter
font_mono=JetBrains Mono
font_size=10
```

```ini
# kome.conf
[General]
Format=1
Preset=mocha

[Units]
rendering=on
kitty=off
```

`[Units]` lists only overrides; each unit's default comes from its metadata.

**Key naming.** Section names are CamelCase (`[Preset]`); every value key in
presets, palettes and styles is lowercase `snake_case`, so it maps directly
to its variable and placeholder: `font_ui` → `KOME_FONT_UI` → `{{font_ui}}`.
`Format` is metadata and is not exported. When a preset is resolved, the
palette is read first, then the style, then the preset, so a preset can
override any value (e.g. its own `accent`).

Separation rule: **global** settings (which units run) live in `kome.conf`;
**per-look** settings live in presets/palettes/styles.

---

## 9. Template and colour engine

- Units fill their templates (e.g. `units/10-colors/kde.colors.in`) from the
  `KOME_*` values.
- Placeholder syntax: inside `{{ }}` goes a role or a function call, with an
  optional output format after `:` (`hex`, the default, or `rgb`):
  `{{accent}}` → `#b4befe`, `{{accent:rgb}}` → `180,190,254` (KDE),
  `{{mix(base,text,0.1):rgb}}`, `{{lighten(base,0.05)}}`,
  `{{darken(crust,0.2)}}`. An unknown placeholder is an error with
  `FILE:LINE` — never silently left empty.
- KDE colour schemes need **derived shades** (hover, inactive, disabled,
  shadows). Plain `sed` cannot do colour maths → a small **POSIX awk** engine
  (`lib/kome/color.awk`): hex↔rgb, mix, lighten/darken, contrast ratio.
- This is the most technically delicate part of the project. Keep it tiny,
  pure and heavily tested (bats).

---

## 10. Font rendering (global, not per preset)

Goal: text as crisp as macOS on the owner's screens (2560×1440 at 125%
fractional scaling).

- **Greyscale antialiasing, no subpixel (RGB).** Subpixel adds colour fringes
  and does not combine well with fractional scaling.
- **Slight (or no) hinting.** Keep true glyph shapes; at this pixel density
  there is enough resolution.
- **FreeType stem darkening** (`FREETYPE_PROPERTIES="cff:no-stem-darkening=0
  autofitter:no-stem-darkening=0"`, via `~/.config/environment.d/`). Emboldens
  stems like macOS; without it Linux text looks thin and washed out. Needs a
  re-login.
- **UI font: Inter** (screen-optimised, closest to San Francisco). Some styles
  may choose a different UI font with the same crispness criteria.
- **Monospace: JetBrains Mono.** Kitty bundles Nerd Font symbols, so no patched
  font is needed for the terminal.
- Also relevant (advice only, `kome doctor`): XWayland apps should "apply
  scaling themselves" to avoid blur; Electron apps should run on native Wayland.

Implementation: a dedicated, opt-in `rendering` unit (separate from `fonts`:
different lifecycle — global, not per preset, needs a re-login), switched on
with `rendering=on` in `kome.conf`. It applies the values above, fixed; there
are no tuning keys. Power users override its commented template (§6). It owns
a user-level fontconfig file + an `environment.d` file. The `original`
snapshot must capture the prior state of both.

---

## 11. Presets (initial set)

**v0.1 ships only `breeze`, `breeze-dark`, Catppuccin Mocha and Catppuccin
Latte** (factory light/dark + one pastel light/dark pair — enough to validate
the engine). The rest arrive in v0.2.

Chosen to be clearly different from each other. All palettes are authored by
`kome` from the official upstream palettes (not third-party KDE ports, whose
quality varies). Each palette file credits its upstream project and keeps its
licence notice (e.g. Catppuccin is MIT, compatible with kome's GPL).

**Licence:** `kome` is **GPL-3.0-or-later** — built on community themes, given
back to the community, like most of the KDE ecosystem.

| # | Preset | Mode | Mood | Accent |
|---|---|---|---|---|
| 0a | breeze | light | KDE factory (Breeze) | Breeze blue |
| 0b | breeze-dark | dark | KDE factory (Breeze Dark) | Breeze blue |
| 1 | Catppuccin Mocha | dark | soft pastel, mauve | lavender |
| 2 | Catppuccin Latte | light | cool pastel, clean | blue |
| 3 | Tokyo Night | dark | night city, soft neon | electric blue |
| 4 | Rosé Pine | dark | earthy, romantic | dusty rose |
| 5 | Rosé Pine Dawn | light | warm, beige paper | mauve |
| 6 | Nord | dark | arctic, cold, muted | ice blue |
| 7 | Everforest | dark | forest, relaxing | sage green |
| 8 | Gruvbox Material | dark | warm retro | ochre orange |
| 9 | Kanagawa | dark | Japanese ink | gold & indigo |

---

## 12. CLI conventions (the "UNIX nerd checklist")

- `-h/--help`, `--version`, `-n/--dry-run` (on `apply`: plan only),
  `-q/--quiet`, `-v/--verbose`.
- Data → stdout; messages → stderr. Colours only on a TTY; honour `NO_COLOR`.
- Every warning/error suggests the exact next command (git-style `hint:`).
- Prompts are `[y/N]` (Enter = no) and only on a TTY.
- Documented exit codes (sysexits-style).
- Man pages written in **scdoc**, shipped pre-generated: `kome(1)` (all
  subcommands) and `kome.conf(5)` (config, preset, palette and style formats).
- Shell completions: bash, zsh, fish.
- Idempotent; a lock file prevents two concurrent `apply`s.
- XDG Base Directory compliant.
- No `curl | sh` without checksums anywhere in docs.

---

## 13. Repository layout (`kome`)

```
kome/
├── bin/kome                     # dispatcher
├── libexec/kome/
│   ├── kome-list kome-apply …   # one executable per subcommand
│   └── units/
│       ├── 10-colors/           # unit, unit metadata, kde.colors.in
│       ├── 20-icons/  30-cursor/  40-fonts/  50-rendering/
│       └── 60-gtk/  70-wallpaper/  90-kitty/
├── lib/kome/
│   ├── common.sh                # logging, errors, hints, INI/template helpers
│   ├── preset.sh                # find/list/resolve presets, palettes, styles
│   ├── ini.awk                  # INI reader for kome's own files
│   ├── color.awk                # colour maths
│   ├── template.awk             # {{placeholder}} filling
│   └── resolve.awk              # preset → KOME_* variables, palette validation
├── share/kome/
│   ├── palettes/  styles/  presets/   # breeze.ini, breeze-dark.ini = KDE factory
│   └── deps/                    # ingredient → package name per package manager
├── doc/man/kome.1.scd  kome.conf.5.scd
├── completions/{bash,zsh,fish}/
├── tests/*.bats
├── .github/workflows/ci.yml     # shellcheck + bats + build man pages
├── Makefile                     # install/uninstall; PREFIX defaults to ~/.local (no root);
│                                # system-wide: sudo make install PREFIX=/usr/local; DESTDIR for packagers
├── README.md  README.es.md  CHANGELOG.md  LICENSE  CLAUDE.md
```

**The repository has the same layout as an installation**, so kome runs
identically from a checkout (`./bin/kome`) and from `$PREFIX`.

Language: POSIX `sh` wherever reasonable (bash only if a clear need appears),
validated with `shellcheck`. Testing Plasma behaviour is manual (a test user or
a nested `kwin_wayland --windowed` session); CI covers shell, generators and
templates only.

---

## 14. Roadmap

- **v0.1** — palette/template engine; units `colors`, `icons`, `cursor`,
  `fonts`, `rendering`, `wallpaper`, `kitty` (GTK follows via Plasma); commands `apply`, `list`,
  `doctor` (+ `--info`, `--fix`), `deps`, `status`, `restore`, `purge`;
  presets `breeze`, `breeze-dark`, `mocha`, `latte`; man pages; completions; CI.
- **v0.2** — remaining presets (§11); units `decoration` (Klassy), `style`,
  `panel` (and Style grows accordingly); GUI picker (`.desktop` + KRunner).
- **Later / maybe** — palette×style mixing from the CLI
  (`--palette nord --style bar`); `kome preview` (automatic screenshots per
  preset for README and picker thumbnails); `kome validate` (format + WCAG
  contrast); light/dark pairs + timer (in `dotfiles`).

---

## 15. Deferred

| Idea | Why deferred |
|---|---|
| Named snapshots (`kome snapshot <name>`) | `original` + `previous` cover the real needs; names bring listing, deletion, retention |
| `kome new <name> --from <preset>` | It is a `cp`; `kome list` hints how to copy a preset meanwhile |
| `--json` output | No consumer yet |
| Material You (accent from wallpaper) | Breaks the "palette is a static file" model |
| Konsole unit | Kitty first; Konsole only recolours new windows |
| Third-party units in `$XDG_DATA_HOME/kome/units/` (would also replace post-apply hooks for VS Code, btop, fastfetch, Vesktop, Firefox…) | Not needed until the core is stable |
| Direct unit subcommand (`kome unit icons apply`) | Units are executables; run them by path |
| Shipped wallpapers | Users keep their own wallpapers; avoids licences and repo size |
| Tuning keys for font rendering in `kome.conf` | Fixed recommended values; power users override the template |
| Distro packages (COPR, AUR, …) | `make install` to `~/.local` is enough until there are users asking |
| Flatpak GTK theming (overrides via `doctor --fix [y/N]`) | Plasma syncs GTK for native apps; Flatpak needs filesystem overrides, which touch another program. Revisit when someone needs it |
| Purge without a manifest (state dir lost): units list the files they generate (all carry "Generated by kome") | Only pre-manifest dev installs have unregistered files; no public user can. Revisit if manifests get lost in practice |

---

## 16. Open questions

- Flatpak-only / immutable systems (Silverblue, Kinoite): what should
  `kome deps` suggest there?
- Should `make uninstall` suggest running `kome purge` first?
- Klassy vs Darkly as the widget style for non-default presets (v0.2).
- Plasma's automatic light/dark theme switching: which kdeglobals key
  enables it (verify on Plasma 6.7) so `kome doctor` can detect it.
- Panel layouts to offer (full bar, floating centred dock, top bar + dock…) and
  their multi-monitor behaviour (v0.2).

---

## 17. Decision log

| Date | Decision |
|---|---|
| 2026-10-20 | Target: KDE Plasma 6 only, any distro. |
| 2026-10-20 | Terminal: Kitty (live theme reload, bundled Nerd Font symbols). |
| 2026-10-20 | Icons: Papirus only (complete coverage). |
| 2026-10-20 | Font rendering: greyscale AA, slight hinting, stem darkening; Inter + JetBrains Mono. Global, not per preset. |
| 2026-10-20 | Two repos: `kome` (tool) and `dotfiles` (personal setup, chezmoi). |
| 2026-10-20 | `kome` never installs packages, never needs root, never syncs. |
| 2026-10-20 | Single abstraction: the unit, with `check` / `apply` / `current`. |
| 2026-10-20 | Single undo primitive: snapshots. |
| 2026-10-20 | Panel unit is opt-in and disabled by default. |
| 2026-10-20 | Config format: INI, read with `kreadconfig6`; `Format=1` in every file. |
| 2026-10-20 | English everywhere in the repo; README in English and Spanish. |
| 2026-10-21 | Audience: public project (friends first, open to all); must be seamless without the owner's `dotfiles`. |
| 2026-10-21 | After apply, kome detects drift (`kome status`) but never fixes it on its own. |
| 2026-10-21 | Font rendering: dedicated `rendering` unit, opt-in, fixed recommended values; power users override its template. |
| 2026-10-21 | Core units (kome's domain) vs integrations (third-party apps). Missing integration target → skip silently; missing ingredient → list clearly, `--partial` to apply anyway. |
| 2026-10-21 | Principle 10: complementary and easy to remove. Principle 11: guided, never manual-dependent. |
| 2026-10-21 | Papirus folder accent via a kome-generated derived icon theme in the user's data dir (no root, Papirus untouched). Replaces `papirus-folders`. |
| 2026-10-21 | User files: kome writes only its own files + at most one `include` line, added only by `kome doctor --fix`. |
| 2026-10-21 | `kome purge`: restore `original` + delete everything in the manifest. |
| 2026-10-21 | KDE factory preset is `breeze`; first snapshot is `original` (kome doesn't care what the previous theme was) and covers every unit. |
| 2026-10-21 | Missing ingredients: kome only *shows* the install command (`kome deps`), per detected package manager; never runs it. |
| 2026-10-21 | `doctor --fix`: reversible fixes applied directly; anything beyond (incl. Flatpak overrides) asks `[y/N]`; skipped without a TTY. |
| 2026-10-21 | v0.1 presets: `breeze`, Mocha, Latte only. |
| 2026-10-21 | No automatic rollback: a failed apply stops and prints the `kome restore` command. |
| 2026-10-21 | Only two snapshots: `original` and `previous`. `kome info` folded into `kome doctor --info`. `kome new`, `--json` deferred. |
| 2026-10-21 | `-n` on `apply` = plan only (units don't implement dry-run). |
| 2026-10-21 | Two man pages: `kome(1)`, `kome.conf(5)`. |
| 2026-10-21 | Palette and style stay separate files so looks can be mixed. Style holds only fonts in v0.1. |
| 2026-10-21 | Units: one directory each, run-parts order (`NN-name`), templates inside, values via `KOME_*` env vars, no inter-unit deps, no `kome unit` subcommand. |
| 2026-10-21 | Wallpaper: user's wallpapers are kept; `wallpaper` unit is opt-in; no shipped wallpapers. |
| 2026-10-21 | D-Bus via `dbus-send`/`busctl`, not `qdbus6`. |
| 2026-10-21 | KDE Look-and-Feel packages are a non-goal (static, reset layout). |
| 2026-10-21 | A failed apply is marked; while marked, `previous` is not overwritten. |
| 2026-10-21 | `check` has documented exit codes: 0 ready, 1 target absent, 2 ingredient missing, 3 other. |
| 2026-10-21 | kome's own INI files are read with `lib/kome/ini.awk`; `kreadconfig6`/`kwriteconfig6` only for KDE's files. Supersedes the 2026-10-20 "read with kreadconfig6". |
| 2026-10-21 | `doctor` detects Plasma features that would undo kome's look; `--fix` offers to disable them (`[y/N]`). |
| 2026-10-21 | One preset = one mode: `breeze` and `breeze-dark` (v0.1 has 4 presets). |
| 2026-10-21 | `make install` defaults to `PREFIX=~/.local` (no root). Distro packaging deferred. |
| 2026-10-21 | `purge` keeps the user's own files in `$XDG_CONFIG_HOME/kome/` and prints their path. |
| 2026-10-21 | `status` shows skipped units as *skipped*, not as drift. |
| 2026-10-21 | Licence: GPL-3.0-or-later. Palettes credit upstream and keep their licence notice. |
| 2026-10-21 | Name: **kome** (米). Free in Fedora, Debian, Arch, AUR, crates.io; no binary/man page clash. Env vars `KOME_*`, paths `…/kome/`. |
| 2026-10-21 | v0.1 design frozen; implementation starts with the repo skeleton. |
| 2026-10-21 | Palette roles: Catppuccin's 26 names + `accent`, values `#rrggbb` only. |
| 2026-10-21 | Repo layout = install layout; units live in `libexec/kome/units/`. |
| 2026-10-21 | Value keys are lowercase snake_case (`font_ui` → `KOME_FONT_UI`); resolution order palette → style → preset (preset overrides). |
| 2026-10-22 | Units get a 4th verb, `restore`, reading `current`'s output on stdin (`current \| restore` is a no-op). |
| 2026-10-22 | Breeze presets use KDE's shipped schemes via `color_scheme=`; no generated imitation. |
| 2026-10-22 | `decoration` stays in v0.2. Klassy is an *optional ingredient*: `check` exits 4, the unit is skipped, the rest is applied, and a notice always says what to install. |
| 2026-10-22 | Unit metadata in a sidecar `unit.ini` (`description`, `kind`, `default`, `takes_effect`, `min_plasma`, `gives`); `kome.conf` `[Units]` overrides `default`. |
| 2026-10-22 | Font size comes from the style (`font_size`, default 10). An empty font name means KDE's default (the key is deleted): Breeze presets stay factory on every distro. |
| 2026-10-22 | Catppuccin presets use the Catppuccin cursors as an optional ingredient (missing → cursor untouched + notice). |
| 2026-10-22 | `icon_accent` is a Papirus folder colour name (Mocha `violet`, Latte `blue`). |
| 2026-10-22 | `kome deps`: package manager detected by binary (dnf, zypper, pacman, apt — first found), names from `share/kome/deps/packages.ini` (only names verified in the distro's index), `url=` for unpackaged ingredients; optional ones after a `# optional` line. |
| 2026-10-22 | `cursor` unit: Catppuccin presets use `catppuccin-<flavour>-<accent>-cursors` (optional); Breeze presets `breeze_cursors`. The deps table gains `install=`, a per-user shell command printed (never run) for unpackaged ingredients. |
| 2026-10-22 | Fix: `original` was frozen at the first apply, so units added later (fonts, cursor) were never saved and `restore original` skipped them. Now each apply first adds to `original` every unit it lacks that kome has never applied (tracked in `$XDG_STATE_HOME/kome/touched`). |
| 2026-10-22 | `icons` unit: preset keys `icon_theme` (Mocha `Papirus-Dark`, Latte `Papirus-Light`, Breeze `breeze`/`breeze-dark`) + `icon_accent`. The accent theme `kome-<preset>-A/B` in `$XDG_DATA_HOME/icons/` inherits from the base and only symlinks folder icons (papirus-folders' rule), found by following `Inherits=`; the base theme is never modified. |
| 2026-10-22 | Fix (found live by the owner): after an icon change the panel kept old icons until hovered. `icons` now signals every KIconLoader group (0–5) plus KGlobalSettings IconChanged (4), as System Settings does. |
| 2026-10-22 | Verified on the owner's machine: switching to a newly used icon theme leaves some panel/desktop icons stale until hovered **even with KDE's own `plasma-changeicons` and plain Papirus-Dark** — a Plasma limitation, not kome's. Documented in the README FAQ; not to be "fixed" again. |
| 2026-10-22 | Manifest: `$XDG_STATE_HOME/kome/manifest`, one `path <absolute path>` line per generated file/dir (units call `manifest_add`); future line kinds (e.g. include lines) get their own keyword. `purge` asks `[y/N]` on a TTY, needs `--yes` otherwise, and deletes only manifest paths inside `$HOME` or the XDG data/config/state dirs. |
| 2026-10-22 | After each apply/restore kome records the expected state per unit in `$XDG_STATE_HOME/kome/applied/`; `kome status` compares `current` against it. |
| 2026-10-22 | `kome doctor`: per-unit ok/missing/optional/off/absent/error lines (exit 1 on missing or error), detects `accentColorFromWallpaper=true` (fixed via `--fix` with `[y/N]`), `--info` facts incl. one line per screen. Automatic light/dark switching detection deferred until its config key is verified. |
| 2026-10-22 | Verified live: GTK followed kome's colours and cursor but not its icons or fonts, because kome wrote kdeglobals without `--notify`. All KDE config writes now use `kwriteconfig6 --notify`. Consequently the `gtk` unit is dropped from v0.1: Plasma's kde-gtk-config does the job. |
| 2026-10-22 | `kitty` integration: colours only (fonts stay the user's) in `kome-theme.conf`; the `include` line is offered by `check` as `fix:` and added by `kome doctor --fix` via the new optional `fix` verb; manifest gains `line<TAB>file<TAB>text` entries, which `purge` removes (deleting the file only if nothing else is left). Template function `by_mode(dark,light)` swaps terminal black/white for light looks. |
| 2026-10-22 | Owner's request: `kome doctor` recommends uninstalled apps kome can theme (`check` exit 1 prints `app:<name>`), with the install command from the deps table (`[app:kitty]`); `kome apply` stays silent about them. Package-manager logic moved to `lib/kome/deps.sh`. |
| 2026-10-22 | Completions for bash, zsh and fish, installed under `$PREFIX/share/{bash-completion/completions,zsh/site-functions,fish/vendor_completions.d}`. They hold no lists: commands come from the new `kome --commands`, presets from `kome list`. |
| 2026-10-22 | Owner moves from Konsole to **Ghostty** (closest to Konsole's comfort, popular for ricing). `ghostty` integration (`91-ghostty`): colours in `kome-theme`, included with `config-file = ?kome-theme` (added by `doctor --fix`), live reload with SIGUSR2; uses `config.ghostty` if present, else `config`. Facts checked in Ghostty's docs. Kitty stays supported. |
| 2026-10-22 | Deps table: `install_<manager>=` for managers that need a full command (Ghostty on Fedora: the community COPR `scottames/ghostty`, as documented by ghostty.org). |
| 2026-10-22 | Fix (tests): the fake Plasma inherited the host PATH, so a real kitty/dnf on the developer's machine changed test results. Tests now run with a hermetic PATH (stubs + basic tools only). |
| 2026-10-22 | Found live (Latte): icons missing from Papirus (e.g. KDE Connect's phone) fell back to a dark variant and showed white on white. The derived icon theme now inherits `<base>,breeze,hicolor` for light looks and `<base>,breeze-dark,hicolor` for dark ones (owner's idea: a mode-matched fallback under the chosen pack). |
| 2026-10-22 | Root cause of the grey/white tray icons (found from the owner's screenshot and index.theme files): the derived theme lacked `FollowsColorScheme=true`, so Plasma stopped recolouring monochrome icons. The derived `[Icon Theme]` now copies every key of the base theme's except Name, Comment, Inherits, Directories, ScaledDirectories and Hidden. KDE Connect probably picks its tray icon at startup (to verify). |
| 2026-10-22 | Plasma keeps old panel icons until hovered (KDE bug 374276, also with `plasma-changeicons`). Owner's decision, a deliberate exception to principle 10's "ask first": kome refreshes the panel automatically, only when an icon change really happened — via systemd's `plasma-plasmashell` unit, or `plasmashell --replace` on systems without systemd; opt-out `RefreshPanel=off`. New `takes_effect=shell`. |
| 2026-10-22 | Fix: re-applying the same look switched `colors`/`icons` between A and B (same content, new name), breaking idempotence and, with the panel refresh, restarting the panel for nothing. Both units now compare what they would generate with the active one and do nothing when identical; they alternate only when the content changes. |
| 2026-10-22 | Verified live: panel refresh after icon changes and idempotent re-apply work on the owner's machine. |

---

## 18. Reference machines (owner's)

Not used by `kome` logic — context for testing and for the `dotfiles` repo.

**HP Victus (primary)**
- Fedora 44, KDE Plasma 6, Wayland. Secure Boot on; NVIDIA driver via akmods
  (signed with an enrolled MOK). Dual boot with Windows 11.
- Hybrid graphics: Intel Raptor Lake iGPU + NVIDIA RTX 4070 Laptop (AD106M).
  Both external outputs (DP, HDMI) are wired to the NVIDIA GPU; the iGPU only
  drives the internal panel.
- Always used lid-closed as a dock: **2 external 2560×1440 monitors, 125%
  fractional scaling on both, 144 Hz and 165 Hz.**
- Monitors are **27"** → ~109 ppi (a Retina display is ~220): a physical
  ceiling on crispness that rendering settings cannot remove.
- Font rendering (2026-10-22): kdeglobals XftAntialias / XftHintStyle /
  XftSubPixel unset (system defaults); `FREETYPE_PROPERTIES` unset (no stem
  darkening). Inter + JetBrains Mono installed via `kome deps mocha`.

**ThinkPad T480 (secondary)**
- Fedora KDE. Other details to be gathered (screen, scaling).

**Still to gather**: exact Plasma/KWin/Qt versions, current colour
scheme/icons/fonts, current font rendering settings, XWayland scaling mode,
current panel layout and widgets, installed themes, Flatpak and Electron apps.
Once `kome doctor --info` exists it replaces this ad-hoc diagnostic.
