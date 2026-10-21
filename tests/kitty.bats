#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The kitty integration, the include-line fix and its purge, against a
# fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	UNIT="$KOME_ROOT/libexec/kome/units/90-kitty/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
	kdir="$XDG_CONFIG_HOME/kitty"
}

@test "without kitty the unit is absent (1) and kome apply ignores it" {
	run "$UNIT" check
	[ "$status" -eq 1 ]
	"$KOME" apply mocha
	[ ! -e "$kdir/kome-theme.conf" ]
}

@test "check announces the include line as a fix" {
	fake_kitty
	run "$UNIT" check
	[ "$status" -eq 0 ]
	[ "$output" = "fix:add \"include kome-theme.conf\" to $kdir/kitty.conf" ]
}

@test "apply writes the theme, reloads kitty, and points to doctor --fix" {
	fake_kitty
	preset_export mocha
	run "$UNIT" apply
	[ "$status" -eq 0 ]
	grep -qx 'background              #1e1e2e' "$kdir/kome-theme.conf"
	grep -qx 'color0  #45475a' "$kdir/kome-theme.conf"
	grep -q 'pkill -USR1 -x kitty' "$LOG"
	[[ "$output" == *"hint: run 'kome doctor --fix'"* ]]
	[ ! -e "$kdir/kitty.conf" ]
}

@test "light looks swap the terminal's black and white" {
	fake_kitty
	preset_export latte
	"$UNIT" apply
	grep -qx 'color0  #5c5f77' "$kdir/kome-theme.conf"
	grep -qx 'color7  #acb0be' "$kdir/kome-theme.conf"
}

@test "doctor --fix appends one line and keeps the user's kitty.conf intact" {
	fake_kitty
	mkdir -p "$kdir"
	printf 'font_size 12\nbackground_opacity 0.9' >"$kdir/kitty.conf"
	run "$KOME" doctor mocha
	[ "$status" -eq 1 ]
	[[ "$output" == *"fix       kitty"* ]]
	run "$KOME" doctor --fix mocha
	[ "$status" -eq 0 ]
	[ "$(cat "$kdir/kitty.conf")" = "$(printf 'font_size 12\nbackground_opacity 0.9\ninclude kome-theme.conf')" ]
	"$KOME" doctor --fix mocha
	[ "$(grep -c 'include kome-theme.conf' "$kdir/kitty.conf")" -eq 1 ]
	run "$KOME" doctor mocha
	[ "$status" -eq 0 ]
}

@test "apply is quiet about kitty once the line is there" {
	fake_kitty
	"$KOME" doctor --fix mocha
	run "$KOME" apply mocha
	[[ "$output" != *"kitty will use"* ]]
}

@test "purge removes the line and the theme, and leaves the rest of kitty.conf" {
	fake_kitty
	mkdir -p "$kdir"
	printf 'font_size 12\n' >"$kdir/kitty.conf"
	"$KOME" apply mocha
	"$KOME" doctor --fix mocha
	"$KOME" purge --yes
	[ "$(cat "$kdir/kitty.conf")" = "font_size 12" ]
	[ ! -e "$kdir/kome-theme.conf" ]
}

@test "purge deletes a kitty.conf kome created, if nothing else is in it" {
	fake_kitty
	"$KOME" apply mocha
	"$KOME" doctor --fix mocha
	[ -f "$kdir/kitty.conf" ]
	"$KOME" purge --yes
	[ ! -e "$kdir/kitty.conf" ]
}

@test "restore brings back the previous theme, or no theme at all" {
	fake_kitty
	"$KOME" apply mocha
	"$KOME" apply latte
	grep -q '#eff1f5' "$kdir/kome-theme.conf"
	"$KOME" restore previous
	grep -q '#1e1e2e' "$kdir/kome-theme.conf"
	"$KOME" restore original
	[ ! -e "$kdir/kome-theme.conf" ]
}

@test "kome status follows the kitty theme too" {
	fake_kitty
	"$KOME" apply mocha
	run "$KOME" status
	[[ "$output" == *"kitty      as applied"* ]]
	printf 'background #000000\n' >>"$kdir/kome-theme.conf"
	run "$KOME" status
	[ "$status" -eq 1 ]
	[[ "$output" == *"kitty      changed by hand"* ]]
}
