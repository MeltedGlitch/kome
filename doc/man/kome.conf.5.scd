kome.conf(5)

# NAME

kome.conf - kome's settings, presets, palettes and styles

# DESCRIPTION

All of kome's files are INI files: *[Section]* headers and *key=value*
lines. Lines starting with *#* or *;* are comments. Values are taken
verbatim after the first *=*: there are no inline comments, so a colour like
*base=#1e1e2e* needs no quoting. Every file may carry *Format=1*.

Your own files live in _~/.config/kome/_ and override the shipped ones with
the same name: copy a shipped file there to change it.

# KOME.CONF

_~/.config/kome/kome.conf_ holds global settings.

*[General]*
	*Preset=*_name_
		The preset used by a bare *kome apply* or *kome deps*.

	*RefreshPanel=on*|*off*
		Whether kome refreshes Plasma's panel after changing icons (default
		*on*). With *off*, kome only says how to do it.

*[Units]*
	_unit_*=on*|*off*
		Turn a unit on or off, overriding its default. *rendering* and
		*wallpaper* are off unless turned on here.

Example:

```
[General]
Preset=mocha

[Units]
rendering=on
wallpaper=on
```

# PRESETS

_presets/<name>.ini_ describes one look. The file name is the preset's name.

```
[Preset]
name=Catppuccin Mocha
palette=catppuccin-mocha
style=soft
mode=dark
icon_theme=Papirus-Dark
icon_accent=violet
cursor_theme=catppuccin-mocha-lavender-cursors
```

*name*
	Full name, shown by *kome list*.

*palette*, *style*
	The palette and style files to use (required). Mixing the palette of one
	look with the style of another is allowed.

*mode*
	*dark* or *light*.

*icon_theme*, *icon_accent*
	The icon theme, and an optional folder colour of that theme (for Papirus:
	*blue*, *violet*, *indigo*, *teal*…).

*cursor_theme*
	The cursor theme (optional: if it is not installed, the cursor is left as
	is).

*color_scheme*
	Use this installed KDE colour scheme instead of generating one from the
	palette (e.g. *BreezeDark*).

*wallpaper*
	An image, as an absolute path or starting with _~/_ (used only when the
	*wallpaper* unit is on).

Any palette or style key may also appear here, and wins: e.g.
*accent=#cba6f7*.

# PALETTES

_palettes/<name>.ini_ has a *[Palette]* section with all 27 colour roles, as
*#rrggbb*:

*base mantle crust surface0 surface1 surface2 overlay0 overlay1 overlay2 text
subtext0 subtext1 rosewater flamingo pink mauve red maroon peach yellow green
teal sky sapphire blue lavender accent*

A palette missing a role, or with a value that is not a colour, is an error.

# STYLES

_styles/<name>.ini_ has a *[Style]* section:

*font_ui*, *font_mono*
	The interface and monospace fonts. Empty means KDE's own default.

*font_size*
	Size in points, a whole number (default 10). Small fonts are 2 points
	less.

# TEMPLATES

Each unit fills its templates from these values. To change what a unit
writes, copy its template to _~/.config/kome/templates/<unit>/_ and edit the
copy. In templates, *{{role}}* is a value, *{{role:rgb}}* a colour as
*r,g,b*, and *mix(a,b,t)*, *lighten(a,t)*, *darken(a,t)* and
*by_mode(dark,light)* derive colours.

# KEYS

Value keys are lowercase *snake_case*; section names are CamelCase.

# SEE ALSO

*kome*(1)
