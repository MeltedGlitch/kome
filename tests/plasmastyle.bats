#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The Plasma style, widget style and effects units (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	U="$KOME_ROOT/libexec/kome/units"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
}

@test "plasmastyle: Klassy's style in the look's mode, through kome's derived style" {
	fake_klassy
	preset_export mocha
	"$U/15-plasmastyle/unit" apply
	[ "$(kcfg plasmarc Theme name)" = "kome-klassy-dark" ]
	preset_export latte
	"$U/15-plasmastyle/unit" apply
	[ "$(kcfg plasmarc Theme name)" = "kome-klassy-light" ]
}

@test "plasmastyle: the derived style has no colours of its own, so the panel takes kome's" {
	fake_klassy
	preset_export mocha
	"$U/15-plasmastyle/unit" apply
	d="$XDG_DATA_HOME/plasma/desktoptheme/kome-klassy-dark"
	[ ! -e "$d/colors" ]
	grep -q '"Id": "kome-klassy-dark"' "$d/metadata.json"
	# Klassy's graphics and settings, never Klassy's own fallback.
	[ "$(sed -n '/^\[Settings\]/,/^\[/p' "$d/plasmarc" | grep -c FallbackTheme)" -eq 1 ]
	grep -qx 'FallbackTheme=klassy-dark' "$d/plasmarc"
	grep -qx '\[ContrastEffect\]' "$d/plasmarc"
	! grep -q breeze-dark "$d/plasmarc"
	# Klassy itself is untouched.
	[ -f "$XDG_DATA_DIRS/plasma/desktoptheme/klassy-dark/colors" ]
	grep -qx "path $d" "$XDG_STATE_HOME/kome/manifest"
}

@test "plasmastyle: re-applying leaves the derived style alone" {
	fake_klassy
	preset_export mocha
	"$U/15-plasmastyle/unit" apply
	d="$XDG_DATA_HOME/plasma/desktoptheme/kome-klassy-dark"
	touch -d '2000-01-01' "$d/plasmarc"
	"$U/15-plasmastyle/unit" apply
	[ "$(find "$d/plasmarc" -newermt '2001-01-01')" = "" ]
	[ "$(grep -c 'plasmastyle' "$LOG")" -eq 1 ]
}

@test "plasmastyle: purge removes the derived style; restore writes it again" {
	fake_klassy
	"$KOME_ROOT/bin/kome" apply mocha 2>/dev/null
	d="$XDG_DATA_HOME/plasma/desktoptheme/kome-klassy-dark"
	[ -d "$d" ]
	saved=$("$U/15-plasmastyle/unit" current)
	"$KOME_ROOT/bin/kome" purge --yes >/dev/null 2>&1
	[ ! -e "$d" ]
	printf '%s\n' "$saved" | "$U/15-plasmastyle/unit" restore
	[ -f "$d/plasmarc" ]
}

@test "plasmastyle: without Klassy, an optional ingredient; Breeze needs nothing" {
	preset_export mocha
	run "$U/15-plasmastyle/unit" check
	[ "$status" -eq 4 ]
	[ "$output" = "decoration:Klassy" ]
	preset_export breeze
	run "$U/15-plasmastyle/unit" check
	[ "$status" -eq 0 ]
}

@test "plasmastyle: Breeze is KDE's \"default\", restore brings the old one back" {
	fake_klassy
	saved=$("$U/15-plasmastyle/unit" current)
	[ "$saved" = "theme=default" ]
	preset_export mocha
	"$U/15-plasmastyle/unit" apply
	printf '%s\n' "$saved" | "$U/15-plasmastyle/unit" restore
	[ "$(kcfg plasmarc Theme name)" = "default" ]
}

@test "plasmastyle: an id that is not installed is named for deps" {
	KOME_PLASMA_STYLE=sweet run "$U/15-plasmastyle/unit" check
	[ "$status" -eq 4 ]
	[ "$output" = "plasma-style:sweet" ]
}

@test "widgets: Klassy's application style, or Breeze, written to kdeglobals" {
	fake_klassy
	preset_export mocha
	"$U/45-widgets/unit" apply
	[ "$(kcfg kdeglobals KDE widgetStyle)" = "Klassy" ]
	preset_export breeze
	"$U/45-widgets/unit" apply
	[ "$(kcfg kdeglobals KDE widgetStyle)" = "Breeze" ]
}

@test "widgets: needs a restart of apps, and restore deletes a key that was unset" {
	fake_klassy
	run "$KOME" apply mocha
	[[ "$output" == *"restart your apps to see"*"buttons, tabs and menus inside apps"* ]]
	"$KOME" restore original
	[ "$(kcfg kdeglobals KDE widgetStyle)" = "" ]
}

@test "effects: blur on and fast animations, loaded at once" {
	preset_export mocha
	"$U/55-effects/unit" apply
	[ "$(kcfg kwinrc Plugins blurEnabled)" = "true" ]
	[ "$(kcfg kdeglobals KDE AnimationDurationFactor)" = "0.5" ]
	grep -q 'org.kde.kwin.Effects.loadEffect string:blur' "$DBUSLOG"
	grep -q 'org.kde.KWin.reconfigure' "$DBUSLOG"
}

@test "effects: every speed maps to KDE's factor; Breeze resets to defaults" {
	for pair in slow:2 fast:0.5 instant:0; do
		KOME_ANIMATION_SPEED=${pair%%:*} "$U/55-effects/unit" apply
		[ "$(kcfg kdeglobals KDE AnimationDurationFactor)" = "${pair#*:}" ]
	done
	preset_export breeze
	"$U/55-effects/unit" apply
	[ "$(kcfg kdeglobals KDE AnimationDurationFactor)" = "" ]
	[ "$(kcfg kwinrc Plugins blurEnabled)" = "" ]
}

@test "effects: unknown values are errors with a hint" {
	KOME_BLUR=maybe run "$U/55-effects/unit" check
	[ "$status" -eq 3 ]
	KOME_ANIMATION_SPEED=ludicrous run "$U/55-effects/unit" check
	[ "$status" -eq 3 ]
	[[ "$output" == *"hint: "* ]]
}

@test "deps lists Klassy once although three units want it" {
	. "$KOME_ROOT/lib/kome/deps.sh"
	printf '#!/bin/sh\n' >"$stubs/dnf"
	chmod +x "$stubs/dnf"
	run "$KOME" deps mocha
	[ "$(printf '%s\n' "$output" | grep -c 'errornointernet/klassy')" -eq 1 ]
}
