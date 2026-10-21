#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The wallpaper unit (opt-in), against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	UNIT="$KOME_ROOT/libexec/kome/units/70-wallpaper/unit"
	img="$HOME/Pictures/wall.jpg"
	mkdir -p "$HOME/Pictures"
	: >"$img"
	mkdir -p "$XDG_CONFIG_HOME/kome"
	# Two screens: one image wallpaper, one slideshow; plus a panel.
	cat >"$XDG_CONFIG_HOME/plasma-org.kde.plasma.desktop-appletsrc" <<'EOF'
[Containments][1]
activityId=abc
formfactor=0
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///home/me/old-left.png

[Containments][2]
formfactor=2
plugin=org.kde.panel

[Containments][7]
activityId=abc
wallpaperplugin=org.kde.slideshow

[Containments][7][Wallpaper][org.kde.slideshow][General]
SlidePaths=/home/me/slides
EOF
}

with_wallpaper() {
	mkdir -p "$XDG_CONFIG_HOME/kome/presets"
	printf '[Preset]\nname=Mine\npalette=catppuccin-mocha\nstyle=soft\nmode=dark\nwallpaper=%s\n' "$1" \
		>"$XDG_CONFIG_HOME/kome/presets/mine.ini"
	printf '[Units]\nwallpaper=on\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
}

@test "it is opt-in, and a preset without wallpaper= changes nothing" {
	"$KOME" apply mocha
	! grep -q '^wallpaper' "$LOG"
	printf '[Units]\nwallpaper=on\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
	"$KOME" apply mocha
	! grep -q '^wallpaper' "$LOG"
}

@test "apply sets the image on the desktops and the lock screen, ~ expanded" {
	with_wallpaper '~/Pictures/wall.jpg'
	run "$KOME" apply mine
	[ "$status" -eq 0 ]
	grep -qx "wallpaper $img" "$LOG"
	[ "$(kcfg kscreenlockerrc 'Greeter/Wallpaper/org.kde.image/General' Image)" = "file://$img" ]
}

@test "a missing or relative wallpaper path stops with a hint" {
	with_wallpaper '~/Pictures/nope.jpg'
	run "$KOME" apply mine
	[ "$status" -eq 69 ]
	KOME_WALLPAPER=relative.jpg run "$UNIT" check
	[ "$status" -eq 3 ]
	[[ "$output" == *"absolute path or start with ~/"* ]]
}

@test "current reads every desktop's plugin and image, but not panels" {
	run "$UNIT" current
	[ "$output" = "$(printf 'desktop.1.plugin=org.kde.image\ndesktop.1.image=file:///home/me/old-left.png\ndesktop.7.plugin=org.kde.slideshow\nlock=')" ]
}

@test "restore puts each screen back through Plasma's scripting" {
	saved=$("$UNIT" current)
	printf '%s\n' "$saved" | "$UNIT" restore
	grep -q "evaluateScript" "$DBUSLOG"
	grep -q "desktopById(1).*wallpaperPlugin = 'org.kde.image'.*writeConfig('Image', 'file:///home/me/old-left.png')" "$DBUSLOG"
	grep -q "desktopById(7); if (d) { d.wallpaperPlugin = 'org.kde.slideshow'; d.reloadConfig(); }" "$DBUSLOG"
	[ "$(kcfg kscreenlockerrc 'Greeter/Wallpaper/org.kde.image/General' Image)" = "" ]
}

@test "quotes in paths cannot break out of the script" {
	printf "desktop.1.plugin=org.kde.image\ndesktop.1.image=file:///x/it's.png\nlock=\n" | "$UNIT" restore
	grep -q "writeConfig('Image', 'file:///x/it\\\\'s.png')" "$DBUSLOG"
}

@test "restore original after an apply asks Plasma for the old wallpapers" {
	with_wallpaper '~/Pictures/wall.jpg'
	"$KOME" apply mine
	"$KOME" restore original
	grep -q "old-left.png" "$DBUSLOG"
}
