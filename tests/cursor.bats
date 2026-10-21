#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The cursor unit, against a fake Plasma (see helpers.bash).

load helpers

setup() {
	fake_plasma
	UNIT="$KOME_ROOT/libexec/kome/units/30-cursor/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
}

# install_cursor <dir> <theme> — a fake cursor theme.
install_cursor() {
	mkdir -p "$1/$2/cursors"
}

@test "current defaults to breeze_cursors when nothing is set" {
	run "$UNIT" current
	[ "$output" = "theme=breeze_cursors" ]
}

@test "a missing theme is an optional ingredient (4)" {
	preset_export mocha
	run "$UNIT" check
	[ "$status" -eq 4 ]
	[ "$output" = "cursor:catppuccin-mocha-lavender-cursors" ]
}

@test "themes are found in ~/.icons, the user's and the system's icon dirs" {
	preset_export mocha
	for dir in "$HOME/.icons" "$XDG_DATA_HOME/icons" "$XDG_DATA_DIRS/icons"; do
		rm -rf "$HOME/.icons" "$XDG_DATA_HOME/icons/catppuccin-mocha-lavender-cursors" \
			"$XDG_DATA_DIRS/icons/catppuccin-mocha-lavender-cursors"
		install_cursor "$dir" catppuccin-mocha-lavender-cursors
		run "$UNIT" check
		[ "$status" -eq 0 ] || { echo "not found in $dir"; false; }
	done
}

@test "apply sets the theme, restore puts the old one back" {
	install_cursor "$HOME/.icons" catppuccin-mocha-lavender-cursors
	preset_export mocha
	saved=$("$UNIT" current)
	"$UNIT" apply
	[ "$(kcfg kcminputrc Mouse cursorTheme)" = "catppuccin-mocha-lavender-cursors" ]
	printf '%s\n' "$saved" | "$UNIT" restore
	[ "$(kcfg kcminputrc Mouse cursorTheme)" = "breeze_cursors" ]
}

@test "apply does nothing when the theme is already set, or none is given" {
	preset_export breeze
	"$UNIT" apply
	! grep -q '^cursor ' "$LOG" 2>/dev/null
	unset KOME_CURSOR_THEME
	"$UNIT" apply
	! grep -q '^cursor ' "$LOG" 2>/dev/null
}

@test "restore without a theme= line is an error" {
	run "$UNIT" restore </dev/null
	[ "$status" -eq 65 ]
}

@test "kome apply without Catppuccin cursors applies the rest and says what to install" {
	run "$KOME_ROOT/bin/kome" apply mocha
	[ "$status" -eq 0 ]
	[ "$(cat "$STATE")" = "Kome-mocha-A" ]
	[[ "$output" == *"install catppuccin-mocha-lavender-cursors to also theme the mouse cursor"* ]]
}

@test "kome deps points to the Catppuccin cursor download" {
	run "$KOME_ROOT/bin/kome" deps mocha
	[[ "$output" == *"# optional"* ]]
	[[ "$output" == *"curl -fL -o /tmp/kome-cursors.zip https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-lavender-cursors.zip"* ]]
	[[ "$output" == *"unzip -o /tmp/kome-cursors.zip -d ~/.local/share/icons"* ]]
}
