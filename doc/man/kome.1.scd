kome(1)

# NAME

kome - change the whole look of KDE Plasma 6 in one command

# SYNOPSIS

*kome* _command_ [_options_] [_preset_]

*kome* *-h* | *--help* | *--version* | *--commands*

# DESCRIPTION

*kome* themes the whole desktop from one palette: the Plasma colour scheme
and accent colour, window decorations, the Plasma style, the widget style of
apps, icons (with folders in the look's accent colour), cursor, fonts, font
rendering, KWin effects, panels, wallpaper, terminals (kitty, Ghostty) and
apps (btop, Vesktop). GTK apps follow through Plasma's own GTK sync.

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

*apply* [*-n*] [*-v*] [*--partial*] [*--palette* _P_] [*--style* _S_] [_preset_]
	Apply a look. Checks every unit first: if something the preset needs is
	missing, nothing is changed (see *deps*). Then saves the desktop and
	applies each unit in order. Applying the same look twice changes nothing.
	A bare *apply* of the active preset keeps the palette and style it was
	mixed with.

	*-n*, *--dry-run*: show what would be applied, change nothing.++
*-v*, *--verbose*: say what each unit does.++
*--partial*: apply what is possible even if something is missing.++
*--palette* _P_, *--style* _S_: mix looks: use another palette or style
	than the preset's (see *list palettes*, *list styles*).

*list* [*presets* | *palettes* | *styles*]
	List the presets (or palettes, or styles): their name, a tab, and their
	full name. Your own files override shipped ones with the same name.

*validate* [_preset_...]
	Check the contrast of each preset's palette (all presets by default):
	text on backgrounds and on the accent, rated by WCAG contrast ratio as
	pass (4.5 or more), warn (3 or more) or fail. Exit status 1 on a fail.

*preview* [*-o* _DIR_] [*-d* _SECONDS_] [_preset_...]
	Apply each preset (all by default), take a screenshot of the desktop
	with *spectacle*(1) as _DIR_/_preset_.png, then put the desktop back
	exactly as it was. *-d* waits that many seconds after each apply
	(default 3). Presets that cannot be applied are skipped.

*status* [*-v*]
	Show the active preset and, for each unit, whether it is still as kome
	left it, was changed by hand since, or was skipped. *-v* shows what changed.

*doctor* [*--info*] [*--fix*] [_preset_]
	Check what each unit can do here and why not: ok, missing (something to
	install), optional, off (opt-in), absent (app not installed, with the
	command to install it) or error. Also detects Plasma settings that would
	undo the look (accent colour from the wallpaper, day/night theme
	switching) and X11 apps that will look blurry with fractional scaling.

	*--info*: also print facts about this system (Plasma and KWin versions,
	session, GPUs, font rendering, screens).++
*--fix*: apply the fixes found. Reversible ones (such as the one include
	line kitty and Ghostty need) are applied directly; anything that changes a
	Plasma setting asks first.

*deps* [_preset_]
	Print the command that installs what the preset is missing, for your
	package manager (dnf, zypper, pacman, apt). kome never runs it. Optional
	extras come after a *# optional* line.

*tui*
	Menus in the terminal to apply a look (the active one preselected),
	undo the last change, go back to your own desktop, see what changed, and
	check this system. Drawn with *dialog*(1) or *whiptail*(1) when one is
	installed, else as plain numbered menus; *KOME_TUI*=*dialog*|*whiptail*|*plain*
	picks one. It only runs the commands below and shows what they say.

*gui*
	The same menus as KDE dialogs (*kdialog*), also in the application
	launcher and KRunner as "kome".

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
|  decoration
:[ window corners and title bar buttons (with Klassy, optional)
:[ on
|  colors
:[ Plasma colour scheme (generated from the palette, or a KDE scheme) and accent colour
:[ on
|  plasmastyle
:[ look of the panel, widgets and notifications (Klassy's, optional)
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
|  widgets
:[ widget style inside apps (Klassy's, optional; new apps only)
:[ on
|  rendering
:[ greyscale antialiasing, slight hinting, stem darkening (needs re-login)
:[ off
|  effects
:[ KWin blur behind panels and menus, animation speed
:[ on
|  panel
:[ panel layout (bar, dock, topbar); replaces every panel and its widgets
:[ off
|  wallpaper
:[ desktop and lock screen, from the preset's *wallpaper=*
:[ off
|  kitty, ghostty
:[ terminal colours (if the terminal is installed)
:[ on
|  btop, vesktop
:[ app colours (if installed); choose the *kome* theme once in the app
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

Mocha's style with Nord's colours:

	kome apply --palette nord mocha

Screenshots of every preset in _~/Pictures/kome_:

	kome preview -o ~/Pictures/kome

# SEE ALSO

*kome.conf*(5), *plasma-apply-colorscheme*(1), *spectacle*(1)

# AUTHORS

MeltedGlitch and contributors. Licensed GPL-3.0-or-later.
