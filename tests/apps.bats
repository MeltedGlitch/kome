#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Integrations whose theme the user chooses inside the app (btop, Vesktop),
# against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	BTOP="$KOME_ROOT/libexec/kome/units/92-btop/unit"
	VESKTOP="$KOME_ROOT/libexec/kome/units/93-vesktop/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
	bdir="$XDG_CONFIG_HOME/btop"
	vdir="$XDG_CONFIG_HOME/vesktop"
}

fake_app() {
	printf '#!/bin/sh\n' >"$stubs/$1"
	chmod +x "$stubs/$1"
}

@test "without btop or Vesktop both units are absent and apply ignores them" {
	run "$BTOP" check
	[ "$status" -eq 1 ]
	[ "$output" = "app:btop" ]
	run "$VESKTOP" check
	[ "$status" -eq 1 ]
	[ "$output" = "app:vesktop" ]
	"$KOME" apply mocha
	[ ! -e "$bdir" ]
	[ ! -e "$vdir" ]
}

@test "btop: check offers no fix, there is no line to add" {
	fake_app btop
	run "$BTOP" check
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "btop: apply writes kome.theme, reloads btop, and says how to choose it" {
	fake_app btop
	preset_export mocha
	run "$BTOP" apply
	[ "$status" -eq 0 ]
	grep -qx 'theme\[main_bg\]="#1e1e2e"' "$bdir/themes/kome.theme"
	grep -qx 'theme\[hi_fg\]="#b4befe"' "$bdir/themes/kome.theme"
	grep -q 'pkill -USR2 -x btop' "$LOG"
	[[ "$output" == *"choose its 'kome' theme"* ]]
	[[ "$output" == *"hint: in btop press Esc"* ]]
	[ ! -e "$bdir/btop.conf" ]
}

@test "btop: quiet once btop.conf uses the kome theme, by name or path" {
	fake_app btop
	preset_export mocha
	mkdir -p "$bdir"
	printf 'color_theme = "kome"\n' >"$bdir/btop.conf"
	run "$BTOP" apply
	[ -z "$output" ]
	printf 'color_theme = "%s/themes/kome.theme"\n' "$bdir" >"$bdir/btop.conf"
	run "$BTOP" apply
	[ -z "$output" ]
	printf 'color_theme = "kome-old"\n' >"$bdir/btop.conf"
	run "$BTOP" apply
	[[ "$output" == *"choose its 'kome' theme"* ]]
}

@test "btop: restore and purge leave btop.conf alone" {
	fake_app btop
	mkdir -p "$bdir"
	printf 'color_theme = "kome"\n' >"$bdir/btop.conf"
	"$KOME" apply mocha
	"$KOME" apply latte
	grep -q '#eff1f5' "$bdir/themes/kome.theme"
	"$KOME" restore previous
	grep -q '#1e1e2e' "$bdir/themes/kome.theme"
	"$KOME" purge --yes
	[ ! -e "$bdir/themes/kome.theme" ]
	[ "$(cat "$bdir/btop.conf")" = 'color_theme = "kome"' ]
}

@test "btop: current | restore changes nothing" {
	fake_app btop
	preset_export mocha
	"$BTOP" apply 2>/dev/null
	before=$(cat "$bdir/themes/kome.theme")
	"$BTOP" current | "$BTOP" restore
	[ "$(cat "$bdir/themes/kome.theme")" = "$before" ]
}

@test "vesktop: apply writes a Vencord theme with kome's colours" {
	fake_app vesktop
	preset_export mocha
	run "$VESKTOP" apply
	[ "$status" -eq 0 ]
	f="$vdir/themes/kome.theme.css"
	grep -q '^ \* @name kome$' "$f"
	grep -q -- '--brand-500: #b4befe !important;' "$f"
	grep -q -- '--background-base-lowest: #11111b !important;' "$f"
	grep -q -- '--mention-background: rgba(180,190,254,0.3);' "$f"
	! grep -q '{{' "$f"
	[[ "$output" == *"hint: in Vesktop open Settings"* ]]
	! grep -q 'pkill' "$LOG"
}

@test "vesktop: quiet once Vencord has the theme enabled" {
	fake_app vesktop
	preset_export latte
	mkdir -p "$vdir/settings"
	printf '{"enabledThemes": ["kome.theme.css"]}\n' >"$vdir/settings/settings.json"
	run "$VESKTOP" apply
	[ -z "$output" ]
	grep -q -- '--background-surface-high: #eff1f5 !important;' "$vdir/themes/kome.theme.css"
}

@test "vesktop: the Flatpak is found and themed in its own data dir" {
	fdir="$HOME/.var/app/dev.vencord.Vesktop"
	mkdir -p "$fdir"
	run "$VESKTOP" check
	[ "$status" -eq 0 ]
	"$KOME" apply mocha 2>/dev/null
	[ -f "$fdir/config/vesktop/themes/kome.theme.css" ]
	[ ! -e "$vdir" ]
	"$KOME" purge --yes
	[ ! -e "$fdir/config/vesktop/themes/kome.theme.css" ]
}

@test "doctor recommends btop and Vesktop with their install commands" {
	fake_app dnf
	run "$KOME" doctor mocha
	[[ "$output" == *"absent    btop "*"sudo dnf install btop"* ]]
	[[ "$output" == *"absent    vesktop "*"flatpak install flathub dev.vencord.Vesktop"* ]]
}
