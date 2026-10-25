#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Presets: finding, listing, resolving (lib/kome/preset.sh, kome list).

setup() {
	KOME_ROOT="$BATS_TEST_DIRNAME/.."
	export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
	user="$XDG_CONFIG_HOME/kome"
}

# user_file <kind/name.ini> <content> — write a user override.
user_file() {
	mkdir -p "$(dirname "$user/$1")"
	printf '%s\n' "$2" >"$user/$1"
}

@test "resolve mocha: palette, style and preset values" {
	run preset_resolve mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"KOME_PRESET=mocha"* ]]
	[[ "$output" == *"KOME_BASE=#1e1e2e"* ]]
	[[ "$output" == *"KOME_ACCENT=#b4befe"* ]]
	[[ "$output" == *"KOME_FONT_UI=Inter"* ]]
	[[ "$output" == *"KOME_FONT_MONO=JetBrains Mono"* ]]
	[[ "$output" == *"KOME_MODE=dark"* ]]
	[[ "$output" == *"KOME_NAME=Catppuccin Mocha"* ]]
	[[ "$output" != *"KOME_FORMAT"* ]]
}

@test "every shipped preset resolves" {
	for p in $(data_list presets); do
		preset_resolve "$p" >/dev/null
	done
}

@test "export puts the values in the environment" {
	preset_export latte
	[ "$KOME_BASE" = "#eff1f5" ]
	[ "$KOME_FONT_MONO" = "JetBrains Mono" ]
}

@test "a user preset overrides a shipped one with the same name" {
	user_file presets/mocha.ini '[Preset]
name=My Mocha
palette=catppuccin-mocha
style=soft'
	run preset_resolve mocha
	[[ "$output" == *"KOME_NAME=My Mocha"* ]]
}

@test "a preset can override a palette value" {
	user_file presets/mine.ini '[Preset]
palette=catppuccin-mocha
style=soft
accent=#cba6f7'
	preset_export mine
	[ "$KOME_ACCENT" = "#cba6f7" ]
}

@test "an unknown preset fails with a hint" {
	run preset_resolve nope
	[ "$status" -eq 64 ]
	[[ "$output" == *"no preset named 'nope'"* ]]
	[[ "$output" == *"hint: run 'kome list'"* ]]
}

@test "preset names cannot be paths" {
	run data_find presets ../presets/mocha
	[ "$status" -eq 1 ]
	run data_find presets .hidden
	[ "$status" -eq 1 ]
}

@test "a palette missing a role is an error naming it" {
	grep -v '^teal=' "$KOME_ROOT/share/kome/palettes/catppuccin-mocha.ini" >"$BATS_TEST_TMPDIR/p"
	user_file palettes/broken.ini "$(cat "$BATS_TEST_TMPDIR/p")"
	user_file presets/b.ini '[Preset]
palette=broken
style=soft'
	run preset_resolve b
	[ "$status" -eq 65 ]
	[[ "$output" == *"palette role 'teal' is missing"* ]]
}

@test "a palette value that is not a colour is an error" {
	sed 's/^red=.*/red=crimson/' "$KOME_ROOT/share/kome/palettes/catppuccin-mocha.ini" >"$BATS_TEST_TMPDIR/p"
	user_file palettes/broken.ini "$(cat "$BATS_TEST_TMPDIR/p")"
	user_file presets/b.ini '[Preset]
palette=broken
style=soft'
	run preset_resolve b
	[ "$status" -eq 65 ]
	[[ "$output" == *"red=crimson is not a colour"* ]]
}

@test "keys must be lowercase snake_case" {
	user_file presets/b.ini '[Preset]
palette=catppuccin-mocha
style=soft
IconAccent=blue'
	run preset_resolve b
	[ "$status" -eq 65 ]
	[[ "$output" == *"'IconAccent' must be lowercase snake_case"* ]]
}

@test "a missing palette or style is an error" {
	user_file presets/b.ini '[Preset]
palette=nope
style=soft'
	run preset_resolve b
	[ "$status" -eq 65 ]
	[[ "$output" == *"no palette named 'nope'"* ]]
	user_file presets/c.ini '[Preset]
palette=catppuccin-mocha'
	run preset_resolve c
	[[ "$output" == *"missing 'style='"* ]]
}

@test "kome list prints name and full name, user presets included" {
	user_file presets/mine.ini '[Preset]
name=Mine
palette=catppuccin-mocha
style=soft'
	run "$KOME_ROOT/bin/kome" list
	[ "$status" -eq 0 ]
	[[ "$output" == *$'latte\tCatppuccin Latte'* ]]
	[[ "$output" == *$'mocha\tCatppuccin Mocha'* ]]
	[[ "$output" == *$'mine\tMine'* ]]
}

@test "kome list rejects arguments and has --help" {
	run "$KOME_ROOT/bin/kome" list extra
	[ "$status" -eq 64 ]
	run "$KOME_ROOT/bin/kome" list --help
	[ "$status" -eq 0 ]
	[[ "$output" == "usage: kome list"* ]]
}

@test "breeze presets point to KDE's shipped schemes" {
	run preset_resolve breeze-dark
	[[ "$output" == *"KOME_COLOR_SCHEME=BreezeDark"* ]]
	run preset_resolve breeze
	[[ "$output" == *"KOME_COLOR_SCHEME=BreezeLight"* ]]
	# Empty font names: KDE's own defaults.
	printf '%s\n' "$output" | grep -qx 'KOME_FONT_UI='
}

@test "melange is an earthy light/dark pair, credited to its authors" {
	run preset_resolve melange-dark
	[[ "$output" == *"KOME_MODE=dark"* ]]
	[[ "$output" == *"KOME_BASE=#292522"* ]]
	[[ "$output" == *"KOME_ACCENT=#e49b5d"* ]]
	[[ "$output" == *"KOME_ICON_ACCENT=palebrown"* ]]
	run preset_resolve melange-light
	[[ "$output" == *"KOME_MODE=light"* ]]
	[[ "$output" == *"KOME_TEXT=#54433a"* ]]
	[[ "$output" == *"KOME_ICON_THEME=Papirus-Light"* ]]
	grep -q 'savq/melange-nvim' "$KOME_ROOT/share/kome/palettes/melange-dark.ini"
	grep -q 'MIT' "$KOME_ROOT/share/kome/palettes/melange-light.ini"
}
