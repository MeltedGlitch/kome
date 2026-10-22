#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome validate: presets resolve and their text pairs are readable.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
}

@test "every shipped preset validates (no fail)" {
	run "$KOME" validate
	[ "$status" -eq 0 ]
	[[ "$output" != *"  fail  "* ]]
}

@test "each pair is rated with its ratio" {
	run "$KOME" validate mocha
	[[ "$output" == *"pass  11.34:1  text on base  (text on views)"* ]]
}

@test "presets on a KDE scheme are not rated on their palette" {
	run "$KOME" validate breeze
	[ "$status" -eq 0 ]
	[[ "$output" == *"desktop colours come from KDE's BreezeLight scheme"* ]]
}

@test "an unreadable palette fails with a hint" {
	mkdir -p "$XDG_CONFIG_HOME/kome/palettes" "$XDG_CONFIG_HOME/kome/presets"
	sed 's/^text=.*/text=#24243a/' "$KOME_ROOT/share/kome/palettes/catppuccin-mocha.ini" \
		>"$XDG_CONFIG_HOME/kome/palettes/murky.ini"
	printf '[Preset]\npalette=murky\nstyle=soft\nmode=dark\n' >"$XDG_CONFIG_HOME/kome/presets/murky.ini"
	run "$KOME" validate murky
	[ "$status" -eq 1 ]
	[[ "$output" == *"fail"*"text on base"* ]]
	[[ "$output" == *"hint: "* ]]
}

@test "a broken preset fails validation" {
	run "$KOME" validate nope
	[ "$status" -eq 1 ]
}
