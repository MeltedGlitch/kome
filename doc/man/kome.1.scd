kome(1)

# NAME

kome - change the whole look of KDE Plasma 6 in one command

# SYNOPSIS

*kome* _command_ [_options_] [_preset_]

*kome* *-h* | *--help* | *--version* | *--commands*

# DESCRIPTION

*kome* themes the whole desktop from one palette: the Plasma colour scheme,
icons (with folders in the look's accent colour), cursor, fonts, font
rendering, wallpaper and terminals (kitty, Ghostty). GTK apps follow through
Plasma's own GTK sync.

It never needs root and never installs packages: it says what to install.
It writes only its own files, and adds at most one include line to a user's
file, and only when asked (*kome doctor --fix*). Before every change it saves
the desktop, so *kome restore original* always brings back the desktop as it
was before kome, and *kome purge* removes every trace of kome.

Every warning or error ends with a *hint:* line giving the next command to
run.

# COMMANDS

Where a command takes a _preset_, it defaults to *Preset=* in *kome.conf*(5),
else the active one.

*apply* [*-n*] [*-v*] [*--partial*] [_preset_]
	Apply a look. Checks every unit first: if something the preset needs is
	missing, nothing is changed (see *deps*). Then saves the desktop and
	applies each unit in order. Applying the same look twice changes nothing.

	*-n*, *--dry-run*: show what would be applied, change nothing.++
*-v*, *--verbose*: say what each unit does.++
*--partial*: apply what is possible even if something is missing.

*list*
	List the presets: their name, a tab, and their full name. Your own presets
	override shipped ones with the same name.

*status* [*-v*]
	Show the active preset and, for each unit, whether it is still as kome
	left it, was changed by hand since, or was skipped. *-v* shows what changed.

*doctor* [*--info*] [*--fix*] [_preset_]
	Check what each unit can do here and why not: ok, missing (something to
	install), optional, off (opt-in), absent (app not installed, with the
	command to install it) or error. Also detects Plasma settings that would
	undo the look (accent colour from the wallpaper).

	*--info*: also print facts about this system (Plasma and KWin versions,
	session, GPUs, font rendering, screens).++
*--fix*: apply the fixes found. Reversible ones (such as the one include
	line kitty and Ghostty need) are applied directly; anything that changes a
	Plasma setting asks first.

*deps* [_preset_]
	Print the command that installs what the preset is missing, for your
	package manager (dnf, zypper, pacman, apt). kome never runs it. Optional
	extras come after a *# optional* line.

*restore* *original* | *previous*
	*original*: the desktop as it was before kome ever changed it.++
*previous*: the desktop before the last *apply*.

*purge* [*-y*]
	Restore *original*, then delete everything kome created (colour schemes,
	icon themes, terminal themes, the lines it added to your files) and its
	snapshots and state. Your own files in _~/.config/kome/_ are kept. Asks
	for confirmation; *-y*, *--yes* skips it (required without a terminal).

# UNITS

Each part of the look is a *unit*, run in this order:

[[ *Unit*
:[ *What it changes*
:[ *Default*
|  colors
:[ Plasma colour scheme (generated from the palette, or a KDE scheme)
:[ on
|  icons
:[ icon theme, folders in the accent colour (a small theme kome generates)
:[ on
|  cursor
:[ mouse cursor theme
:[ on
|  fonts
:[ every KDE font role, from the style
:[ on
|  rendering
:[ greyscale antialiasing, slight hinting, stem darkening (needs re-login)
:[ off
|  wallpaper
:[ desktop and lock screen, from the preset's *wallpaper=*
:[ off
|  kitty, ghostty
:[ terminal colours (if the terminal is installed)
:[ on

Turn units on or off in the *[Units]* section of *kome.conf*(5).

When kome changes the icons it refreshes Plasma's panel, which otherwise
keeps old icons until hovered; *RefreshPanel=off* in *kome.conf*(5) turns
that into a hint.

# EXIT STATUS

[[ *Code*
:[ *Meaning*
|  0
:[ success
|  1
:[ *status*: something was changed by hand; *doctor*: something is wrong
|  64
:[ wrong usage (unknown command, option or preset)
|  65
:[ a malformed preset, palette, style or template
|  66
:[ *restore*: there is no such snapshot yet
|  69
:[ something the preset needs is missing, or a unit cannot run here
|  70
:[ a unit failed while applying or restoring
|  75
:[ another kome is already changing the desktop

# FILES

_~/.config/kome/kome.conf_
	Settings, see *kome.conf*(5).

_~/.config/kome/{presets,palettes,styles,templates}/_
	Your own files; they override shipped ones with the same name.

_~/.local/share/kome/snapshots/_
	The *original* and *previous* snapshots.

_~/.local/state/kome/_
	The active preset, the manifest of what kome created, and the lock.

All of them follow *XDG_CONFIG_HOME*, *XDG_DATA_HOME* and *XDG_STATE_HOME*.

# EXAMPLES

Try a look, then go back:

	kome apply mocha++
kome restore original

See what a preset needs and install it:

	kome deps mocha

Give a terminal kome's colours:

	kome doctor --fix

# SEE ALSO

*kome.conf*(5), *plasma-apply-colorscheme*(1)

# AUTHORS

MeltedGlitch and contributors. Licensed GPL-3.0-or-later.
