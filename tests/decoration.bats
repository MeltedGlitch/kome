#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The decoration unit (Klassy or Breeze), against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	UNIT="$KOME_ROOT/libexec/kome/units/05-decoration/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
}

deco() { kcfg kwinrc org.kde.kdecoration2 "$1"; }
klassy() { kcfg klassy/klassyrc "$1" "$2"; }

@test "without Klassy the windows are left alone, with a notice" {
	preset_export mocha
	run "$UNIT" check
	[ "$status" -eq 4 ]
	[ "$output" = "decoration:Klassy" ]
	run "$KOME" apply mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"install Klassy to also theme window borders and buttons"* ]]
	[ "$(deco library)" = "" ]
}

@test "with Klassy: engine, 8px corners, accent circles on the right" {
	fake_klassy
	preset_export mocha
	"$UNIT" apply
	[ "$(deco library)" = "org.kde.klassy" ]
	[ "$(deco theme)" = "Klassy" ]
	[ "$(deco ButtonsOnLeft)" = "M" ]
	[ "$(deco ButtonsOnRight)" = "IAX" ]
	[ "$(klassy Windeco WindowCornerRadius)" = "8" ]
	[ "$(klassy Windeco ButtonShape)" = "ShapeSmallCircle" ]
	[ "$(klassy ButtonColors ButtonBackgroundColorsActive)" = "Accent" ]
	[ "$(klassy ButtonColors NegativeCloseBackgroundHoverPressActive)" = "true" ]
	# Circles always visible, icons only on hover — Klassy's default would
	# show the circles on hover only (found live).
	[ "$(klassy ButtonBehaviour ShowBackgroundNormallyActive)" = "true" ]
	[ "$(klassy ButtonBehaviour ShowCloseBackgroundNormallyInactive)" = "true" ]
	[ "$(klassy ButtonBehaviour ShowIconNormallyActive)" = "false" ]
	[ "$(klassy ButtonBehaviour ShowCloseIconNormallyActive)" = "false" ]
	[ "$(klassy ButtonColors ButtonBackgroundOpacityActive)" = "100" ]
	grep -q 'org.kde.KWin.reconfigure' "$DBUSLOG"
}

@test "Klassy settings kome does not own are never touched" {
	fake_klassy
	kwriteconfig6 --file klassy/klassyrc --group Windeco --key ButtonIconStyle StyleOxygen
	kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize Tiny
	preset_export mocha
	"$UNIT" apply
	[ "$(klassy Windeco ButtonIconStyle)" = "StyleOxygen" ]
	[ "$(deco BorderSize)" = "Tiny" ]
}

@test "Breeze presets go back to KDE's own decoration and button layout" {
	fake_klassy
	preset_export mocha
	"$UNIT" apply
	preset_export breeze-dark
	"$UNIT" apply
	[ "$(deco library)" = "org.kde.breeze" ]
	[ "$(deco theme)" = "Breeze" ]
	[ "$(deco ButtonsOnRight)" = "" ]
	[ "$(deco ButtonsOnLeft)" = "" ]
}

@test "restore original brings back the user's decoration exactly" {
	fake_klassy
	kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
	kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight HIAX
	"$KOME" apply mocha
	"$KOME" restore original
	[ "$(deco library)" = "org.kde.breeze" ]
	[ "$(deco theme)" = "" ]
	[ "$(deco ButtonsOnRight)" = "HIAX" ]
	[ "$(klassy Windeco WindowCornerRadius)" = "" ]
}

@test "unknown decoration or button style is an error with a hint" {
	KOME_DECORATION=fancy run "$UNIT" check
	[ "$status" -eq 3 ]
	[[ "$output" == *"hint: "* ]]
	KOME_DECORATION=breeze KOME_WINDOW_BUTTONS=squares run "$UNIT" check
	[ "$status" -eq 3 ]
}

@test "deps gives the Klassy COPR on Fedora" {
	. "$KOME_ROOT/lib/kome/deps.sh"
	KOME_PM=dnf KOME_INSTALL="sudo dnf install" run deps_commands "decoration:Klassy"
	[ "$output" = "sudo dnf copr enable errornointernet/klassy && sudo dnf install klassy" ]
}

@test "switching from circles to icons flips every visibility key" {
	fake_klassy
	preset_export mocha
	"$UNIT" apply
	KOME_WINDOW_BUTTONS=icons "$UNIT" apply
	[ "$(klassy ButtonBehaviour ShowBackgroundNormallyActive)" = "false" ]
	[ "$(klassy ButtonBehaviour ShowIconNormallyActive)" = "true" ]
	[ "$(klassy Windeco ButtonShape)" = "ShapeIntegratedRoundedRectangle" ]
}
