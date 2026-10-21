#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome doctor, against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
}

@test "all good: every unit ok (or optional), exit 0" {
	run "$KOME" doctor breeze-dark
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: breeze-dark"* ]]
	[[ "$output" == *"ok        colors     Plasma colour scheme"* ]]
	[[ "$output" == *"ok        icons"* ]]
}

@test "a missing ingredient is a problem, with a deps hint" {
	rm -rf "$XDG_DATA_DIRS/icons/Papirus-Dark"
	run "$KOME" doctor mocha
	[ "$status" -eq 1 ]
	[[ "$output" == *"missing   icons      needs Papirus-Dark"* ]]
	[[ "$output" == *"hint: run 'kome deps mocha'"* ]]
}

@test "an optional ingredient is reported but is not a problem" {
	run "$KOME" doctor mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"optional  cursor     install catppuccin-mocha-lavender-cursors to also theme the mouse cursor"* ]]
}

@test "off and absent units are explained" {
	fake_unit 50-rendering 0 "" default=off "description=Crisp font rendering"
	fake_unit 90-kitty 1 "" default=on "description=Kitty terminal"
	run "$KOME" doctor mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"off       rendering  Crisp font rendering (opt-in: add rendering=on under [Units] in kome.conf)"* ]]
	[[ "$output" == *"absent    kitty      Kitty terminal (its app is not installed)"* ]]
}

@test "a unit that cannot run shows its reason" {
	fake_unit 10-colors 3 "" default=on
	run "$KOME" doctor mocha
	[ "$status" -eq 1 ]
	[[ "$output" == *"error     colors"* ]]
}

@test "without a preset, doctor uses the active one" {
	"$KOME" apply latte
	run "$KOME" doctor
	[[ "$output" == *"preset: latte"* ]]
}

@test "without any preset, doctor checks only the system" {
	run "$KOME" doctor
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: none"* ]]
}

@test "accent from wallpaper is detected; --fix asks and skips without a terminal" {
	kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper true
	run "$KOME" doctor mocha
	[ "$status" -eq 1 ]
	[[ "$output" == *"takes the accent colour from the wallpaper"* ]]
	[[ "$output" == *"hint: run 'kome doctor --fix'"* ]]
	run "$KOME" doctor --fix mocha </dev/null
	[ "$status" -eq 1 ]
	[[ "$output" == *"skipped (not a terminal)"* ]]
	[ "$(kcfg kdeglobals General accentColorFromWallpaper)" = "true" ]
}

@test "--fix with nothing to fix says so" {
	run "$KOME" doctor --fix mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"nothing to fix"* ]]
}

@test "--info prints facts without failing when tools are missing" {
	run "$KOME" doctor --info mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"session:"* ]]
	[[ "$output" == *"stem_darkening: off"* ]]
	FREETYPE_PROPERTIES="cff:no-stem-darkening=0" run "$KOME" doctor --info mocha
	[[ "$output" == *"stem_darkening: on"* ]]
}

@test "doctor rejects unknown options" {
	run "$KOME" doctor --nope
	[ "$status" -eq 64 ]
}

@test "a unit needing a newer Plasma than this one is reported" {
	fake_unit 10-colors 0 "" default=on "description=Colours" min_plasma=6.8
	PLASMA_VERSION=6.7.5 run "$KOME" doctor mocha
	[ "$status" -eq 1 ]
	[[ "$output" == *"error     colors     needs Plasma 6.8 or newer (this is 6.7.5)"* ]]
	PLASMA_VERSION=6.10.0 run "$KOME" doctor mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"ok        colors"* ]]
}
