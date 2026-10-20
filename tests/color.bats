#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Colour maths (lib/kome/color.awk).

setup() {
	KOME_ROOT="$BATS_TEST_DIRNAME/.."
	COLOR="$KOME_ROOT/lib/kome/color.awk"
	. "$KOME_ROOT/lib/kome/common.sh"
}

# calc <awk expression> — print the expression evaluated with color.awk loaded.
calc() {
	printf 'BEGIN { print %s }\n' "$1" >"$BATS_TEST_TMPDIR/prog.awk"
	kome_awk -f "$COLOR" -f "$BATS_TEST_TMPDIR/prog.awk"
}

@test "decimals never depend on the user's locale" {
	locale -a 2>/dev/null | grep -qix 'es_ES.utf-\{0,1\}8' || skip "es_ES.UTF-8 locale not installed"
	LC_ALL=es_ES.UTF-8 LC_NUMERIC=es_ES.UTF-8 run calc 'sprintf("%.1f", 0.5)'
	[ "$output" = "0.5" ]
}

@test "valid colours are #rrggbb, any case" {
	run calc 'color_valid("#1e1e2e") color_valid("#B4BEFE")'
	[ "$output" = "11" ]
}

@test "invalid colours are rejected" {
	run calc 'color_valid("1e1e2e") color_valid("#fff") color_valid("#1e1e2g") color_valid("#1e1e2e0") color_valid("")'
	[ "$output" = "00000" ]
}

@test "rgb gives KDE's r,g,b format" {
	run calc 'color_rgb("#b4befe")'
	[ "$output" = "180,190,254" ]
	run calc 'color_rgb("#000000") " " color_rgb("#FFFFFF")'
	[ "$output" = "0,0,0 255,255,255" ]
}

@test "mix at 0 and 1 returns each end, lowercase" {
	run calc 'color_mix("#1E1E2E", "#cdd6f4", 0) " " color_mix("#1e1e2e", "#CDD6F4", 1)'
	[ "$output" = "#1e1e2e #cdd6f4" ]
}

@test "mix at 0.5 rounds to nearest" {
	run calc 'color_mix("#000000", "#ffffff", 0.5)'
	[ "$output" = "#808080" ]
}

@test "mix clamps when t is out of range" {
	run calc 'color_mix("#808080", "#ffffff", 2) " " color_mix("#808080", "#000000", 2)'
	[ "$output" = "#ffffff #000000" ]
}

@test "lighten and darken move towards white and black" {
	run calc 'color_lighten("#000000", 0.25) " " color_darken("#ffffff", 0.25)'
	[ "$output" = "#404040 #bfbfbf" ]
}

@test "invalid input gives an empty result" {
	run calc '"[" color_rgb("nope") color_mix("#000000", "x", 0.5) color_lighten("", 0.1) "]"'
	[ "$output" = "[]" ]
}

@test "luminance of black and white" {
	run calc 'color_luminance("#000000") " " color_luminance("#ffffff")'
	[ "$output" = "0 1" ]
}

@test "contrast: black on white is 21, a colour on itself is 1" {
	run calc 'sprintf("%.2f %.2f", color_contrast("#000000", "#ffffff"), color_contrast("#1e1e2e", "#1e1e2e"))'
	[ "$output" = "21.00 1.00" ]
}

@test "contrast is symmetric" {
	run calc 'sprintf("%.4f %.4f", color_contrast("#cdd6f4", "#1e1e2e"), color_contrast("#1e1e2e", "#cdd6f4"))'
	[ "${lines[0]%% *}" = "${lines[0]##* }" ]
}

@test "contrast: #767676 on white is the WCAG AA threshold (4.54)" {
	run calc 'sprintf("%.2f", color_contrast("#767676", "#ffffff"))'
	[ "$output" = "4.54" ]
}

@test "contrast of an invalid colour is -1" {
	run calc 'color_contrast("#000000", "bad")'
	[ "$output" = "-1" ]
}
