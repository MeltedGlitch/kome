#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Unit metadata (unit.ini) and how kome apply uses it, with fake units.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
}

conf() {
	mkdir -p "$XDG_CONFIG_HOME/kome"
	printf '%s\n' "$1" >"$XDG_CONFIG_HOME/kome/kome.conf"
}

@test "every shipped unit has valid metadata" {
	. "$KOME_ROOT/lib/kome/common.sh"
	for ini in "$KOME_ROOT"/libexec/kome/units/*/unit.ini; do
		get() { ini_get "$ini" Unit "$1"; }
		[ -n "$(get description)" ] || { echo "$ini: description"; false; }
		[ -n "$(get gives)" ] || { echo "$ini: gives"; false; }
		case $(get kind) in core | integration) ;; *) echo "$ini: kind"; false ;; esac
		case $(get default) in on | off) ;; *) echo "$ini: default"; false ;; esac
		case $(get takes_effect) in live | restart | relogin) ;; *) echo "$ini: takes_effect"; false ;; esac
		[[ "$(get min_plasma)" =~ ^6\.[0-9]+$ ]] || { echo "$ini: min_plasma"; false; }
	done
}

@test "units run in NN order" {
	fake_unit 20-second 0 "" default=on
	fake_unit 10-first 0 "" default=on
	"$KOME" apply mocha
	[ "$(cat "$UNITLOG")" = "$(printf 'first apply\nsecond apply')" ]
}

@test "an opt-in unit (default=off) runs only when kome.conf turns it on" {
	fake_unit 50-rendering 0 "" default=off
	"$KOME" apply mocha
	[ ! -e "$UNITLOG" ]
	conf '[Units]
rendering=on'
	"$KOME" apply mocha
	[ "$(cat "$UNITLOG")" = "rendering apply" ]
}

@test "kome.conf can turn off a unit that is on by default" {
	fake_unit 10-colors 0 "" default=on
	conf '[Units]
colors=off'
	run "$KOME" apply -v mocha
	[ ! -e "$UNITLOG" ]
	[[ "$output" == *"colors: off"* ]]
}

@test "a missing optional ingredient skips its unit, applies the rest, and says so" {
	fake_unit 10-colors 0 "" default=on
	fake_unit 80-decoration 4 "decoration:Klassy" default=on "gives=window borders and buttons"
	run "$KOME" apply mocha
	[ "$status" -eq 0 ]
	[ "$(cat "$UNITLOG")" = "colors apply" ]
	[[ "$output" == *"kome: install Klassy to also theme window borders and buttons"* ]]
	[[ "$output" == *"hint: run 'kome deps mocha'"* ]]
}

@test "units that need a re-login or restart say so after applying" {
	fake_unit 50-rendering 0 "" default=on takes_effect=relogin "gives=crisper text"
	fake_unit 60-style 0 "" default=on takes_effect=restart "gives=the widget style"
	run "$KOME" apply mocha
	[[ "$output" == *"kome: log out and back in to see crisper text"* ]]
	[[ "$output" == *"kome: restart your apps to see the widget style"* ]]
}

@test "snapshots cover disabled units too" {
	fake_unit 50-rendering 0 "" default=off
	"$KOME" apply mocha
	[ "$(cat "$XDG_DATA_HOME/kome/snapshots/original/rendering")" = "state=rendering" ]
}

@test "a unit added after the first apply joins original with the user's state" {
	fake_unit 10-colors 0 "" default=on
	"$KOME" apply mocha
	[ ! -e "$XDG_DATA_HOME/kome/snapshots/original/fonts" ]
	fake_unit 40-fonts 0 "" default=on
	"$KOME" apply mocha
	[ "$(cat "$XDG_DATA_HOME/kome/snapshots/original/fonts")" = "state=fonts" ]
	[ "$(cat "$XDG_STATE_HOME/kome/touched")" = "$(printf 'colors\nfonts')" ]
}

@test "a unit kome already applied is never added to original later" {
	fake_unit 10-colors 0 "" default=on
	"$KOME" apply mocha
	rm "$XDG_DATA_HOME/kome/snapshots/original/colors"
	"$KOME" apply mocha
	[ ! -e "$XDG_DATA_HOME/kome/snapshots/original/colors" ]
}
