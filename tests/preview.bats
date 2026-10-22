#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome preview, against a fake Plasma (helpers.bash) and a fake spectacle.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	shots="$BATS_TEST_TMPDIR/shots"
	cat >"$stubs/spectacle" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
	[ "$1" != --output ] || { printf 'png\n' >"$2"; printf 'spectacle %s\n' "$2" >>"$LOG"; }
	shift
done
EOF
	chmod +x "$stubs/spectacle"
}

@test "preview takes one screenshot per preset and prints their paths" {
	run "$KOME" preview -d 0 -o "$shots" mocha latte
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "$shots/mocha.png" ]
	[ "${lines[1]}" = "$shots/latte.png" ]
	[ -s "$shots/mocha.png" ]
	[ -s "$shots/latte.png" ]
}

@test "preview puts the desktop back exactly, hand-made changes included" {
	"$KOME" apply breeze
	kwriteconfig6 --file kdeglobals --group General --key font "My Font,11"
	before=$(kcfg kdeglobals General font)
	"$KOME" preview -d 0 -o "$shots" mocha latte >/dev/null
	[ "$(kcfg kdeglobals General font)" = "$before" ]
	[ "$(cat "$XDG_STATE_HOME/kome/active")" = breeze ]
	[ "$(kcfg kdeglobals General ColorScheme)" = BreezeLight ]
}

@test "preview on a desktop kome never changed leaves no active preset" {
	"$KOME" preview -d 0 -o "$shots" mocha >/dev/null
	[ ! -e "$XDG_STATE_HOME/kome/active" ]
	run "$KOME" status
	[[ "$output" == *"preset: none"* ]]
}

@test "a preset that cannot be applied is skipped with a hint" {
	: >"$FONTS"
	run "$KOME" preview -d 0 -o "$shots" mocha breeze
	[ "$status" -eq 0 ]
	[[ "$output" == *"skipped mocha"* ]]
	[[ "$output" == *"kome deps mocha"* ]]
	[ -s "$shots/breeze.png" ]
	[ ! -e "$shots/mocha.png" ]
}

@test "preview checks its arguments before changing anything" {
	run "$KOME" preview nope
	[ "$status" -eq 64 ]
	[[ "$output" == *"no preset named 'nope'"* ]]
	run "$KOME" preview -d soon mocha
	[ "$status" -eq 64 ]
	[ ! -d "$XDG_DATA_HOME/kome/snapshots" ]
}

@test "preview needs spectacle" {
	rm "$stubs/spectacle"
	run "$KOME" preview mocha
	[ "$status" -ne 0 ]
	[[ "$output" == *spectacle* ]]
	[ ! -d "$XDG_DATA_HOME/kome/snapshots" ]
}

@test "preview refuses after a failed apply" {
	"$KOME" apply breeze
	: >"$XDG_STATE_HOME/kome/failed"
	run "$KOME" preview -d 0 mocha
	[ "$status" -eq 75 ]
	[[ "$output" == *"kome restore previous"* ]]
}
