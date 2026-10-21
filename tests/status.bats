#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome status, against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
}

@test "before any apply, status says so with a hint" {
	run "$KOME" status
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: none"* ]]
	[[ "$output" == *"hint: run 'kome list'"* ]]
}

@test "right after an apply everything is as applied" {
	"$KOME" apply mocha
	run "$KOME" status
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: mocha (Catppuccin Mocha)"* ]]
	[[ "$output" == *"colors     as applied"* ]]
	[[ "$output" == *"fonts      as applied"* ]]
	[[ "$output" == *"icons      as applied"* ]]
}

@test "a unit that was not applied shows as skipped, not as drift" {
	mkdir -p "$XDG_CONFIG_HOME/kome"
	printf '[Units]\nfonts=off\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
	"$KOME" apply mocha
	run "$KOME" status
	[ "$status" -eq 0 ]
	[[ "$output" == *"fonts      skipped"* ]]
}

@test "a change by hand is drift: exit 1, a hint, and -v shows it" {
	"$KOME" apply mocha
	kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze
	run "$KOME" status
	[ "$status" -eq 1 ]
	[[ "$output" == *"icons      changed by hand"* ]]
	[[ "$output" == *"colors     as applied"* ]]
	[[ "$output" == *"hint: run 'kome apply mocha'"* ]]
	run "$KOME" status -v
	[[ "$output" == *"now: theme=breeze"* ]]
	[[ "$output" == *"was: theme=kome-mocha-A"* ]]
}

@test "re-applying the preset clears the drift" {
	"$KOME" apply mocha
	kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze
	"$KOME" apply mocha
	run "$KOME" status
	[ "$status" -eq 0 ]
}

@test "after restore original, the restored desktop is the expected one" {
	"$KOME" apply mocha
	"$KOME" restore original
	run "$KOME" status
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: none (your original desktop)"* ]]
	[[ "$output" == *"colors     as applied"* ]]
}

@test "after restore previous, status names the previous preset" {
	"$KOME" apply mocha
	"$KOME" apply latte
	"$KOME" restore previous
	run "$KOME" status
	[ "$status" -eq 0 ]
	[[ "$output" == *"preset: mocha"* ]]
}

@test "a failed apply is reported" {
	"$KOME" apply mocha
	FAIL_APPLY=1 run "$KOME" apply latte
	run "$KOME" status
	[[ "$output" == *"the last apply failed"* ]]
	[[ "$output" == *"kome restore previous"* ]]
}
