#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome apply and kome restore, end to end against a fake Plasma.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	snaps="$XDG_DATA_HOME/kome/snapshots"
	state="$XDG_STATE_HOME/kome"
}

user_file() {
	mkdir -p "$(dirname "$XDG_CONFIG_HOME/kome/$1")"
	printf '%s\n' "$2" >"$XDG_CONFIG_HOME/kome/$1"
}

@test "apply: saves original and previous, applies, records the preset" {
	run "$KOME" apply mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"kome: restart your apps to see the fonts of Plasma and KDE apps"* ]]
	[ "$(cat "$STATE")" = "Kome-mocha-A" ]
	grep -qx "scheme=BreezeDark" "$snaps/original/colors"
	grep -qx "scheme=BreezeDark" "$snaps/previous/colors"
	[ "$(cat "$state/active")" = "mocha" ]
	[ ! -e "$state/lock" ]
}

@test "a second apply updates previous but never original" {
	"$KOME" apply mocha
	"$KOME" apply latte
	[ "$(cat "$STATE")" = "Kome-latte-A" ]
	grep -qx "scheme=Kome-mocha-A" "$snaps/previous/colors"
	[ "$(cat "$snaps/previous/.preset")" = "mocha" ]
	grep -qx "scheme=BreezeDark" "$snaps/original/colors"
}

@test "restore previous undoes the last apply, restore original undoes all" {
	"$KOME" apply mocha
	"$KOME" apply latte
	run "$KOME" restore previous
	[ "$status" -eq 0 ]
	[ "$(cat "$STATE")" = "Kome-mocha-A" ]
	[ "$(cat "$state/active")" = "mocha" ]
	run "$KOME" restore original
	[ "$status" -eq 0 ]
	[ "$(cat "$STATE")" = "BreezeDark" ]
	[ ! -e "$state/active" ]
}

@test "a KDE scheme preset applies the shipped scheme" {
	printf 'BreezeLight\n' >"$STATE"
	"$KOME" apply breeze-dark
	[ "$(cat "$STATE")" = "BreezeDark" ]
}

@test "-n shows the plan and changes nothing" {
	run "$KOME" apply -n mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: mocha (Catppuccin Mocha)"* ]]
	[[ "$output" == *"apply: colors"* ]]
	[[ "$output" == *"KOME_BASE=#1e1e2e"* ]]
	[ ! -e "$LOG" ]
	[ ! -d "$snaps" ]
}

@test "-v says what each unit did" {
	run "$KOME" apply -v mocha
	[[ "$output" == *"colors: applied"* ]]
}

@test "without a preset, apply uses Preset= from kome.conf" {
	user_file kome.conf '[General]
Preset=latte'
	"$KOME" apply
	[ "$(cat "$STATE")" = "Kome-latte-A" ]
}

@test "without a preset or kome.conf, apply fails with a hint" {
	run "$KOME" apply
	[ "$status" -eq 64 ]
	[[ "$output" == *"no preset given"* ]]
	[[ "$output" == *"hint: run 'kome list'"* ]]
}

@test "an unknown preset fails before saving anything" {
	run "$KOME" apply nope
	[ "$status" -eq 64 ]
	[ ! -d "$snaps" ]
}

@test "a unit turned off in kome.conf is not applied, but is still saved" {
	user_file kome.conf '[Units]
colors=off'
	"$KOME" apply mocha
	[ ! -e "$LOG" ]
	grep -qx "scheme=BreezeDark" "$snaps/original/colors"
}

@test "a missing ingredient stops apply, --partial applies the rest" {
	user_file presets/odd.ini '[Preset]
palette=catppuccin-mocha
style=soft
color_scheme=NotInstalled'
	run "$KOME" apply odd
	[ "$status" -eq 69 ]
	[[ "$output" == *"color-scheme:NotInstalled  (colors)"* ]]
	[[ "$output" == *"kome deps odd"* ]]
	[[ "$output" == *"kome apply --partial odd"* ]]
	[ ! -d "$snaps" ]
	run "$KOME" apply --partial odd
	[ "$status" -eq 0 ]
	[ ! -e "$LOG" ]
}

@test "a failed apply keeps the last good previous" {
	"$KOME" apply mocha
	FAIL_APPLY=1 run "$KOME" apply latte
	[ "$status" -eq 70 ]
	[[ "$output" == *"hint: run 'kome restore previous'"* ]]
	[ -e "$state/failed" ]
	grep -qx "scheme=Kome-mocha-A" "$snaps/previous/colors"
	printf 'Broken\n' >"$STATE"
	FAIL_APPLY=1 run "$KOME" apply latte
	[[ "$output" == *"the last apply failed"* ]]
	grep -qx "scheme=Kome-mocha-A" "$snaps/previous/colors"
	"$KOME" apply latte
	[ ! -e "$state/failed" ]
}

@test "only one kome changes the desktop at a time" {
	mkdir -p "$state/lock"
	run "$KOME" apply mocha
	[ "$status" -eq 75 ]
	[[ "$output" == *"hint: "* ]]
	[ ! -e "$LOG" ]
}

@test "restore before any apply explains what to do" {
	run "$KOME" restore original
	[ "$status" -eq 66 ]
	[[ "$output" == *"hint: run 'kome apply <preset>' first"* ]]
}

@test "restore needs original or previous" {
	run "$KOME" restore
	[ "$status" -eq 64 ]
	run "$KOME" restore yesterday
	[ "$status" -eq 64 ]
}

@test "apply rejects unknown options and two presets" {
	run "$KOME" apply --nope mocha
	[ "$status" -eq 64 ]
	run "$KOME" apply mocha latte
	[ "$status" -eq 64 ]
}

@test "without a preset or kome.conf, apply re-applies the active one" {
	"$KOME" apply latte
	"$KOME" apply
	[ "$(cat "$XDG_STATE_HOME/kome/active")" = "latte" ]
}

@test "kome.conf's Preset= wins over the active one, for every command" {
	"$KOME" apply latte
	mkdir -p "$XDG_CONFIG_HOME/kome"
	printf '[General]\nPreset=mocha\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
	run "$KOME" doctor
	[[ "$output" == *"preset: mocha"* ]]
	run "$KOME" apply -n
	[[ "$output" == *"preset: mocha"* ]]
}
