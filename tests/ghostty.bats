#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The Ghostty integration, against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	UNIT="$KOME_ROOT/libexec/kome/units/91-ghostty/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
	gdir="$XDG_CONFIG_HOME/ghostty"
}

@test "without Ghostty the unit is absent and names the app" {
	run "$UNIT" check
	[ "$status" -eq 1 ]
	[ "$output" = "app:ghostty" ]
}

@test "apply writes the theme and reloads Ghostty with SIGUSR2" {
	fake_ghostty
	preset_export mocha
	run "$UNIT" apply
	[ "$status" -eq 0 ]
	grep -qx 'background = #1e1e2e' "$gdir/kome-theme"
	grep -qx 'palette = 0=#45475a' "$gdir/kome-theme"
	grep -q 'pkill -USR2 -x ghostty' "$LOG"
	[[ "$output" == *"kome doctor --fix"* ]]
}

@test "light looks swap black and white" {
	fake_ghostty
	preset_export latte
	"$UNIT" apply
	grep -qx 'palette = 0=#5c5f77' "$gdir/kome-theme"
}

@test "fix uses config.ghostty if it exists, else config" {
	fake_ghostty
	"$KOME" doctor --fix mocha
	grep -qx 'config-file = ?kome-theme' "$gdir/config"
	rm -rf "$gdir"
	mkdir -p "$gdir"
	printf 'font-size = 12' >"$gdir/config.ghostty"
	"$KOME" doctor --fix mocha
	[ "$(cat "$gdir/config.ghostty")" = "$(printf 'font-size = 12\nconfig-file = ?kome-theme')" ]
	[ ! -e "$gdir/config" ]
}

@test "purge takes the line out and leaves the user's config as it was" {
	fake_ghostty
	mkdir -p "$gdir"
	printf 'font-size = 12\n' >"$gdir/config.ghostty"
	"$KOME" apply mocha
	"$KOME" doctor --fix mocha
	"$KOME" purge --yes
	[ "$(cat "$gdir/config.ghostty")" = "font-size = 12" ]
	[ ! -e "$gdir/kome-theme" ]
}

@test "restore previous brings back the previous Ghostty theme" {
	fake_ghostty
	"$KOME" apply mocha
	"$KOME" apply latte
	"$KOME" restore previous
	grep -qx 'background = #1e1e2e' "$gdir/kome-theme"
}

@test "deps knows Ghostty's per-manager install command" {
	. "$KOME_ROOT/lib/kome/deps.sh"
	KOME_PM=dnf KOME_INSTALL="sudo dnf install" run deps_commands "app:ghostty"
	[ "$output" = "sudo dnf copr enable scottames/ghostty && sudo dnf install ghostty" ]
	KOME_PM=pacman KOME_INSTALL="sudo pacman -S --needed" run deps_commands "app:ghostty"
	[ "$output" = "sudo pacman -S --needed ghostty" ]
}
