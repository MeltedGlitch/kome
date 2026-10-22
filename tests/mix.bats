#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Mixing looks (kome apply --palette/--style) and kome list's kinds.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	state="$XDG_STATE_HOME/kome"
}

@test "list palettes and styles, with their full names" {
	run "$KOME" list palettes
	[[ "$output" == *$'nord\tNord'* ]]
	[[ "$output" == *$'catppuccin-mocha\tCatppuccin Mocha'* ]]
	run "$KOME" list styles
	[[ "$output" == *$'soft\tSoft'* ]]
	[[ "$output" == *$'breeze\tBreeze'* ]]
	run "$KOME" list presets
	[[ "$output" == *$'mocha\tCatppuccin Mocha'* ]]
	run "$KOME" list shapes
	[ "$status" -eq 64 ]
}

@test "--palette takes another look's colours, keeping the preset's style" {
	run "$KOME" apply -n --palette nord mocha
	[[ "$output" == *"preset: mocha (Catppuccin Mocha), palette nord"* ]]
	[[ "$output" == *"KOME_BASE=#2e3440"* ]]
	[[ "$output" == *"KOME_FONT_UI=Inter"* ]]
	[[ "$output" != *"KOME_WITH_"* ]]
}

@test "--style takes another look's shape, keeping the preset's colours" {
	run "$KOME" apply -n --style breeze mocha
	[[ "$output" == *"KOME_BASE=#1e1e2e"* ]]
	[[ "$output" == *"KOME_DECORATION=breeze"* ]]
}

@test "a mixed look is remembered: status shows it, a bare apply keeps it" {
	"$KOME" apply --palette nord mocha
	run "$KOME" status
	[[ "$output" == *"preset: mocha (Catppuccin Mocha), palette nord"* ]]
	run "$KOME" apply -n
	[[ "$output" == *"palette nord"* ]]
	"$KOME" apply mocha
	[ ! -e "$state/active.palette" ]
}

@test "an unknown --palette is a usage error with a hint" {
	run "$KOME" apply --palette nope mocha
	[ "$status" -eq 64 ]
	[[ "$output" == *"no palette named 'nope'"* ]]
	[[ "$output" == *"hint: run 'kome list palettes'"* ]]
	run "$KOME" apply --style
	[ "$status" -eq 64 ]
}

@test "a preset naming a palette that does not exist is a data error" {
	mkdir -p "$XDG_CONFIG_HOME/kome/presets"
	printf '[Preset]\npalette=gone\nstyle=soft\n' >"$XDG_CONFIG_HOME/kome/presets/odd.ini"
	run "$KOME" apply odd
	[ "$status" -eq 65 ]
}
