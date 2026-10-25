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
	# Circles and their symbols always visible — Klassy's default would
	# show the circles on hover only (found live), and symbols only on hover
	# looked broken to the owner.
	[ "$(klassy ButtonBehaviour ShowBackgroundNormallyActive)" = "true" ]
	[ "$(klassy ButtonBehaviour ShowCloseBackgroundNormallyInactive)" = "true" ]
	[ "$(klassy ButtonBehaviour ShowIconNormallyActive)" = "true" ]
	[ "$(klassy ButtonBehaviour ShowCloseIconNormallyActive)" = "true" ]
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

@test "circle colours come from the palette: soft symbols in the circle's own hue" {
	fake_klassy
	preset_export mocha
	"$UNIT" apply
	# Mocha: lavender circle (180,190,254); symbol = lavender halfway to base.
	[ "$(klassy ButtonColors ButtonOverrideColorsActiveMinimize)" = '{"BackgroundNormal":[180,190,254],"BackgroundHover":[165,174,233],"BackgroundPress":[150,158,212],"IconNormal":[105,110,150],"IconHover":[90,94,129],"IconPress":[90,94,129]}' ]
	klassy ButtonColors ButtonOverrideColorsActiveClose | grep -q '"BackgroundHover":\['
	klassy ButtonColors ButtonOverrideColorsInactiveMaximize | grep -q '"BackgroundNormal":\[105,110,150\]'
	# Klassy must not replace the soft symbol with black or white.
	[ "$(klassy ButtonColors OnPoorIconContrastActive)" = "Nothing" ]
	[ "$(klassy ButtonColors OnPoorIconContrastInactive)" = "Nothing" ]
}

@test "light looks get symbols lighter than the circle" {
	fake_klassy
	preset_export latte
	"$UNIT" apply
	# Latte: blue circle (30,102,245); symbol pulled towards the light base.
	klassy ButtonColors ButtonOverrideColorsActiveMaximize | grep -q '"IconNormal":\[135,172,245\]'
}

@test "icons and Breeze drop the circle colours again" {
	fake_klassy
	preset_export mocha
	"$UNIT" apply
	KOME_WINDOW_BUTTONS=icons "$UNIT" apply
	[ "$(klassy ButtonColors ButtonOverrideColorsActiveClose)" = "" ]
	[ "$(klassy ButtonColors OnPoorIconContrastActive)" = "" ]
}

@test "a user's copy of button-colors.in wins" {
	fake_klassy
	mkdir -p "$KOME_USER_DIR/templates/decoration"
	sed 's/IconNormal":\[{{mix(accent,base,0.5):rgb}}\]/IconNormal":[{{text:rgb}}]/' \
		"$KOME_ROOT/libexec/kome/units/05-decoration/button-colors.in" >"$KOME_USER_DIR/templates/decoration/button-colors.in"
	preset_export mocha
	"$UNIT" apply
	klassy ButtonColors ButtonOverrideColorsActiveMinimize | grep -q '"IconNormal":\[205,214,244\]'
}

@test "the decoration keeps current | restore a no-op with the colours" {
	fake_klassy
	preset_export mocha
	"$UNIT" apply
	before=$("$UNIT" current)
	printf '%s\n' "$before" | "$UNIT" restore
	[ "$("$UNIT" current)" = "$before" ]
	printf '%s\n' "$before" | grep -q '^minimize={"BackgroundNormal"'
}
