#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Template engine (lib/kome/template.awk and the template_* helpers).

setup() {
	KOME_ROOT="$BATS_TEST_DIRNAME/.."
	. "$KOME_ROOT/lib/kome/common.sh"
	t="$BATS_TEST_TMPDIR/test.in"
	export KOME_BASE='#1e1e2e' KOME_TEXT='#CDD6F4' KOME_ACCENT='#b4befe'
	export KOME_FONT_UI='Inter'
}

# fill <template text> — fill a one-off template.
fill() {
	printf '%s\n' "$1" >"$t"
	template_fill "$t"
}

@test "text without placeholders is copied as is" {
	run fill 'Name=kome }} not a placeholder'
	[ "$status" -eq 0 ]
	[ "$output" = 'Name=kome }} not a placeholder' ]
}

@test "a name gives its value verbatim" {
	run fill 'font={{font_ui}} text={{text}}'
	[ "$output" = 'font=Inter text=#CDD6F4' ]
}

@test ":hex normalises a colour, :rgb gives r,g,b" {
	run fill '{{text:hex}} {{accent:rgb}}'
	[ "$output" = '#cdd6f4 180,190,254' ]
}

@test "several placeholders on one line, spaces ignored" {
	run fill 'A={{ base : rgb }};B={{accent}}'
	[ "$output" = 'A=30,30,46;B=#b4befe' ]
}

@test "mix, lighten and darken, with names and literals" {
	run fill '{{mix(#000000,#ffffff,0.5)}} {{lighten(#000000,0.25)}} {{darken(#ffffff, .25)}}'
	[ "$output" = '#808080 #404040 #bfbfbf' ]
	run fill '{{mix(base,text,0):rgb}} {{mix(base,text,1)}}'
	[ "$output" = '30,30,46 #cdd6f4' ]
}

@test "the output keeps every line, including empty ones" {
	printf '[A]\n\nk={{base}}\n' >"$t"
	run template_fill "$t"
	[ "${#lines[@]}" -eq 2 ]
	[ "$(template_fill "$t" | wc -l)" -eq 3 ]
}

@test "an unknown name is an error with file:line" {
	printf 'ok\nk={{nope}}\n' >"$t"
	run template_fill "$t"
	[ "$status" -eq 65 ]
	[[ "$output" == *"test.in:2: unknown value 'nope' (KOME_NOPE is not set)"* ]]
}

@test "an unclosed {{ is an error" {
	run fill 'k={{base'
	[ "$status" -eq 65 ]
	[[ "$output" == *"not closed"* ]]
}

@test "empty and invalid names are errors" {
	run fill '{{}}'
	[ "$status" -eq 65 ]
	run fill '{{Base}}'
	[ "$status" -eq 65 ]
}

@test "unknown function and wrong argument count are errors" {
	run fill '{{blend(base,text,0.5)}}'
	[[ "$output" == *"unknown function 'blend()'"* ]]
	run fill '{{mix(base,text)}}'
	[[ "$output" == *"mix() takes 3 arguments"* ]]
	run fill '{{lighten(base)}}'
	[ "$status" -eq 65 ]
}

@test "amounts must be numbers from 0 to 1" {
	run fill '{{mix(base,text,1.5)}}'
	[[ "$output" == *"not a number from 0 to 1"* ]]
	run fill '{{mix(base,text,x)}}'
	[ "$status" -eq 65 ]
	run fill '{{lighten(base,1)}}'
	[ "$status" -eq 0 ]
}

@test "colour formats and functions reject non-colours" {
	run fill '{{font_ui:rgb}}'
	[[ "$output" == *"not a colour"* ]]
	run fill '{{lighten(font_ui,0.1)}}'
	[[ "$output" == *"not a colour"* ]]
}

@test "an unknown format is an error" {
	run fill '{{base:hsl}}'
	[[ "$output" == *"unknown format ':hsl'"* ]]
}

@test "render writes the file and creates its directory" {
	printf 'k={{accent:rgb}}\n' >"$t"
	run template_render "$t" "$BATS_TEST_TMPDIR/out/dir/file.colors"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/out/dir/file.colors")" = 'k=180,190,254' ]
}

@test "render leaves the old file untouched on error" {
	dest="$BATS_TEST_TMPDIR/file.colors"
	printf 'old\n' >"$dest"
	printf 'k={{nope}}\n' >"$t"
	run template_render "$t" "$dest"
	[ "$status" -eq 65 ]
	[ "$(cat "$dest")" = 'old' ]
	[ ! -e "$dest.kome-tmp" ]
}

@test "by_mode picks the dark or light colour from KOME_MODE" {
	KOME_MODE=dark run fill '{{by_mode(base,text)}}'
	[ "$output" = '#1e1e2e' ]
	KOME_MODE=light run fill '{{by_mode(base,text):rgb}}'
	[ "$output" = '205,214,244' ]
	KOME_MODE= run fill '{{by_mode(base,text)}}'
	[ "$status" -eq 65 ]
	[[ "$output" == *"needs mode=dark or mode=light"* ]]
}
