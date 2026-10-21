#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The colors unit, against a fake Plasma (see helpers.bash).

load helpers

setup() {
	fake_plasma
	UNIT="$KOME_ROOT/libexec/kome/units/10-colors/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
}

@test "check passes with Plasma's tools present" {
	run "$UNIT" check
	[ "$status" -eq 0 ]
}

@test "check fails with 3 when Plasma's tools are missing" {
	bin="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$bin"
	for t in sh dirname cat; do ln -s "$(command -v "$t")" "$bin/$t"; done
	PATH="$bin" run "$UNIT" check
	[ "$status" -eq 3 ]
	[[ "$output" == *"plasma-apply-colorscheme not found"* ]]
	[[ "$output" == *"hint: "* ]]
}

@test "check reports a missing KDE scheme as an ingredient (2)" {
	KOME_COLOR_SCHEME=Nope run "$UNIT" check
	[ "$status" -eq 2 ]
	[ "$output" = "color-scheme:Nope" ]
	KOME_COLOR_SCHEME=BreezeDark run "$UNIT" check
	[ "$status" -eq 0 ]
}

@test "current prints the active scheme" {
	run "$UNIT" current
	[ "$output" = "scheme=BreezeDark" ]
}

@test "apply generates a complete scheme and applies it" {
	preset_export mocha
	run "$UNIT" apply
	[ "$status" -eq 0 ]
	f="$XDG_DATA_HOME/color-schemes/Kome-mocha-A.colors"
	[ -f "$f" ]
	[ "$(cat "$LOG")" = "Kome-mocha-A" ]
	! grep -q '{{' "$f"
	[ "$(ini_get_kde "$f" 'Colors:View' BackgroundNormal)" = "30,30,46" ]
	[ "$(ini_get_kde "$f" 'Colors:Selection' BackgroundNormal)" = "180,190,254" ]
	[ "$(ini_get_kde "$f" General ColorScheme)" = "Kome-mocha-A" ]
	[ "$(ini_get_kde "$f" General Name)" = "kome: Catppuccin Mocha" ]
}

@test "applying the same colours twice changes nothing" {
	preset_export mocha
	"$UNIT" apply
	"$UNIT" apply
	[ "$(tr '\n' ' ' <"$LOG")" = "Kome-mocha-A " ]
}

@test "changed colours alternate names and never overwrite the active scheme" {
	preset_export mocha
	"$UNIT" apply
	KOME_ACCENT='#cba6f7' "$UNIT" apply
	"$UNIT" apply
	[ "$(tr '\n' ' ' <"$LOG")" = "Kome-mocha-A Kome-mocha-B Kome-mocha-A " ]
}

@test "apply uses a KDE scheme as is when color_scheme is set" {
	preset_export mocha
	KOME_COLOR_SCHEME=BreezeDark run "$UNIT" apply
	[ "$status" -eq 0 ]
	[ "$(cat "$LOG")" = "BreezeDark" ]
	[ ! -d "$XDG_DATA_HOME/color-schemes" ]
}

@test "apply prefers the user's copy of the template" {
	mkdir -p "$XDG_CONFIG_HOME/kome/templates/colors"
	printf '[General]\nColorScheme={{scheme}}\nName=custom {{accent}}\n' \
		>"$XDG_CONFIG_HOME/kome/templates/colors/kde.colors.in"
	preset_export mocha
	"$UNIT" apply
	grep -qx 'Name=custom #b4befe' "$XDG_DATA_HOME/color-schemes/Kome-mocha-A.colors"
}

@test "a broken template fails and applies nothing" {
	mkdir -p "$XDG_CONFIG_HOME/kome/templates/colors"
	printf 'x={{nope}}\n' >"$XDG_CONFIG_HOME/kome/templates/colors/kde.colors.in"
	preset_export mocha
	run "$UNIT" apply
	[ "$status" -eq 65 ]
	[ ! -e "$LOG" ]
}

@test "restore re-applies what current printed" {
	preset_export mocha
	saved=$("$UNIT" current)
	"$UNIT" apply
	printf '%s\n' "$saved" | "$UNIT" restore
	[ "$(cat "$STATE")" = "BreezeDark" ]
}

@test "current | restore changes nothing" {
	"$UNIT" current | "$UNIT" restore
	[ ! -e "$LOG" ]
}

@test "restore without a scheme= line is an error" {
	run "$UNIT" restore </dev/null
	[ "$status" -eq 65 ]
	[[ "$output" == *"hint: "* ]]
}

@test "an unknown verb is a usage error" {
	run "$UNIT" frobnicate
	[ "$status" -eq 64 ]
	[[ "$output" == *"usage: unit"* ]]
}

@test "the template fills for every shipped palette" {
	for p in $(data_list presets); do
		preset_export "$p"
		KOME_SCHEME=test template_fill "$(template_find colors kde.colors.in)" >/dev/null
	done
}

# ini_get_kde <file> <group> <key> — read a KDE-style file (nested groups
# like [Colors:Header][Inactive] are not supported by ini.awk on purpose).
ini_get_kde() {
	awk -v g="[$2]" -v k="$3" '
		/^\[/ { in_g = ($0 == g); next }
		in_g && index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }
	' "$1"
}
