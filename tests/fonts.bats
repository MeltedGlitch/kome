#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The fonts unit, against a fake Plasma (see helpers.bash).

load helpers

setup() {
	fake_plasma
	UNIT="$KOME_ROOT/libexec/kome/units/40-fonts/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
}

@test "check passes when the fonts are installed" {
	preset_export mocha
	run "$UNIT" check
	[ "$status" -eq 0 ]
}

@test "check lists missing font families as ingredients (2)" {
	printf 'Noto Sans\n' >"$FONTS"
	preset_export mocha
	run "$UNIT" check
	[ "$status" -eq 2 ]
	[ "$output" = "$(printf 'font:Inter\nfont:JetBrains Mono')" ]
}

@test "check ignores empty families (KDE's default)" {
	: >"$FONTS"
	preset_export breeze
	run "$UNIT" check
	[ "$status" -eq 0 ]
}

@test "apply sets every role at the style's size, small fonts 2pt less" {
	preset_export mocha
	run "$UNIT" apply
	[ "$status" -eq 0 ]
	[ "$(kcfg kdeglobals General font)" = "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals General fixed)" = "JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals General smallestReadableFont)" = "Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals General toolBarFont)" = "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals General menuFont)" = "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals WM activeFont)" = "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	grep -q 'KGlobalSettings.notifyChange int32:1' "$DBUSLOG"
}

@test "apply honours font_size" {
	preset_export mocha
	KOME_FONT_SIZE=11 "$UNIT" apply
	[ "$(kcfg kdeglobals General font)" = "Inter,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals General smallestReadableFont)" = "Inter,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
}

@test "apply rejects a font_size that is not a whole number" {
	preset_export mocha
	KOME_FONT_SIZE=10.5 run "$UNIT" apply
	[ "$status" -eq 65 ]
	[[ "$output" == *"hint: "* ]]
}

@test "empty families delete the keys, so KDE's defaults apply" {
	preset_export mocha
	"$UNIT" apply
	preset_export breeze
	"$UNIT" apply
	[ "$(kcfg kdeglobals General font)" = "" ]
	[ "$(kcfg kdeglobals General fixed)" = "" ]
	[ "$(kcfg kdeglobals WM activeFont)" = "" ]
}

@test "restore brings back exactly what current printed, unset keys included" {
	kwriteconfig6 --file kdeglobals --group General --key font "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
	saved=$("$UNIT" current)
	[[ "$saved" == *"font=Noto Sans,10"* ]]
	[[ "$saved" == *"fixed="* ]]
	preset_export mocha
	"$UNIT" apply
	printf '%s\n' "$saved" | "$UNIT" restore
	[ "$(kcfg kdeglobals General font)" = "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	[ "$(kcfg kdeglobals General fixed)" = "" ]
	[ "$("$UNIT" current)" = "$saved" ]
}

@test "kome apply and restore original drive the fonts too" {
	"$KOME_ROOT/bin/kome" apply mocha
	[ "$(kcfg kdeglobals General font)" = "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" ]
	"$KOME_ROOT/bin/kome" restore original
	[ "$(kcfg kdeglobals General font)" = "" ]
}
