#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome purge and the manifest, against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	state="$XDG_STATE_HOME/kome"
}

@test "units record what they generate in the manifest" {
	"$KOME" apply mocha
	"$KOME" apply mocha
	[ "$(grep -c 'Kome-mocha-' "$state/manifest")" -eq 1 ]
	# A changed palette makes a second scheme, which is recorded too.
	mkdir -p "$XDG_CONFIG_HOME/kome/presets"
	printf '[Preset]\nname=Mocha\npalette=catppuccin-mocha\nstyle=soft\nmode=dark\nicon_theme=Papirus-Dark\nicon_accent=violet\naccent=#cba6f7\n' \
		>"$XDG_CONFIG_HOME/kome/presets/mocha.ini"
	"$KOME" apply mocha
	grep -qx "path $XDG_DATA_HOME/color-schemes/Kome-mocha-A.colors" "$state/manifest"
	grep -qx "path $XDG_DATA_HOME/color-schemes/Kome-mocha-B.colors" "$state/manifest"
	grep -qx "path $XDG_DATA_HOME/icons/kome-mocha-A" "$state/manifest"
	[ "$(grep -c 'Kome-mocha-A.colors' "$state/manifest")" -eq 1 ]
}

@test "purge restores the original desktop and deletes all kome made" {
	"$KOME" apply mocha
	"$KOME" apply latte
	run "$KOME" purge --yes
	[ "$status" -eq 0 ]
	[ "$(cat "$STATE")" = "BreezeDark" ]
	[ "$(kcfg kdeglobals General font)" = "" ]
	[ "$(kcfg kdeglobals Icons Theme)" = "" ]
	[ -z "$(ls "$XDG_DATA_HOME/color-schemes" 2>/dev/null)" ]
	[ -z "$(ls "$XDG_DATA_HOME/icons" 2>/dev/null)" ]
	[ ! -d "$XDG_DATA_HOME/kome" ]
	[ ! -d "$state" ]
}

@test "purge keeps the user's own files and says where they are" {
	mkdir -p "$XDG_CONFIG_HOME/kome/presets"
	printf '[General]\nPreset=mocha\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
	"$KOME" apply
	run "$KOME" purge --yes
	[ -f "$XDG_CONFIG_HOME/kome/kome.conf" ]
	[[ "$output" == *"kept your own files in $XDG_CONFIG_HOME/kome"* ]]
	[[ "$output" == *"hint: "* ]]
}

@test "purge never deletes paths outside the home directory" {
	"$KOME" apply mocha
	outside="$BATS_TEST_TMPDIR/outside"
	mkdir -p "$outside"
	printf 'path %s\npath %s/../escape\n' "$outside" "$HOME" >>"$state/manifest"
	"$KOME" purge --yes
	[ -d "$outside" ]
}

@test "purge before any apply is harmless" {
	run "$KOME" purge --yes
	[ "$status" -eq 0 ]
	[ "$(cat "$STATE")" = "BreezeDark" ]
}

@test "without a terminal, purge needs --yes" {
	"$KOME" apply mocha
	run "$KOME" purge </dev/null
	[ "$status" -eq 64 ]
	[[ "$output" == *"kome purge --yes"* ]]
	[ -d "$XDG_DATA_HOME/kome/snapshots/original" ]
}

@test "purge rejects unknown arguments" {
	run "$KOME" purge --force
	[ "$status" -eq 64 ]
}
