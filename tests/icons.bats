#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The icons unit, against a fake Plasma and fake icon themes (helpers.bash).

load helpers

setup() {
	fake_plasma
	UNIT="$KOME_ROOT/libexec/kome/units/20-icons/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
	user_icons="$XDG_DATA_HOME/icons"
}

@test "check passes when the theme and its accent exist" {
	preset_export mocha
	run "$UNIT" check
	[ "$status" -eq 0 ]
}

@test "a missing icon theme is a required ingredient (2)" {
	rm -rf "$XDG_DATA_DIRS/icons/Papirus-Dark"
	preset_export mocha
	run "$UNIT" check
	[ "$status" -eq 2 ]
	[ "$output" = "icons:Papirus-Dark" ]
}

@test "an accent the theme does not have is an error with a hint" {
	preset_export mocha
	KOME_ICON_ACCENT=plaid run "$UNIT" check
	[ "$status" -eq 3 ]
	[[ "$output" == *"has no 'plaid' folders"* ]]
	[[ "$output" == *"hint: "* ]]
}

@test "apply derives a folder theme that inherits from the base theme" {
	preset_export mocha
	run "$UNIT" apply
	[ "$status" -eq 0 ]
	t="$user_icons/kome-mocha-A"
	[ "$(kcfg kdeglobals Icons Theme)" = "kome-mocha-A" ]
	grep -qx 'Inherits=Papirus-Dark' "$t/index.theme"
	grep -qx 'Name=kome: Catppuccin Mocha' "$t/index.theme"
	grep -q '^Directories=.*22x22/places' "$t/index.theme"
	grep -qx '\[48x48/places\]' "$t/index.theme"
	grep -qx 'Size=48' "$t/index.theme"
	grep -q 'KIconLoader.iconChanged' "$DBUSLOG"
}

@test "every icon group is told to reload, so the panel repaints too" {
	preset_export mocha
	"$UNIT" apply
	for g in 0 1 2 3 4 5; do
		grep -q "KIconLoader.iconChanged int32:$g\$" "$DBUSLOG" || { echo "group $g"; false; }
	done
	grep -q 'KGlobalSettings.notifyChange int32:4 int32:0' "$DBUSLOG"
	: >"$DBUSLOG"
	printf 'theme=\n' | "$UNIT" restore
	grep -q 'KIconLoader.iconChanged int32:4$' "$DBUSLOG"
}

@test "folders point at the accent's real files, found through Inherits" {
	preset_export mocha
	"$UNIT" apply
	t="$user_icons/kome-mocha-A/22x22/places"
	papirus="$XDG_DATA_DIRS/icons/Papirus/22x22/places"
	[ "$(readlink "$t/folder.svg")" = "$papirus/folder-violet.svg" ]
	[ "$(readlink "$t/folder-documents.svg")" = "$papirus/folder-violet-documents.svg" ]
	[ "$(readlink "$t/user-home.svg")" = "$papirus/user-violet-home.svg" ]
	[ ! -e "$t/folder-blue.svg" ]
}

@test "the base theme is never modified" {
	before=$(find "$XDG_DATA_DIRS/icons" -exec ls -ld {} + | md5sum)
	preset_export mocha
	"$UNIT" apply
	[ "$(find "$XDG_DATA_DIRS/icons" -exec ls -ld {} + | md5sum)" = "$before" ]
}

@test "apply alternates A/B and never rewrites the active theme" {
	preset_export mocha
	"$UNIT" apply
	"$UNIT" apply
	[ "$(kcfg kdeglobals Icons Theme)" = "kome-mocha-B" ]
	[ -d "$user_icons/kome-mocha-A" ]
	"$UNIT" apply
	[ "$(kcfg kdeglobals Icons Theme)" = "kome-mocha-A" ]
}

@test "without an accent the theme is set as is" {
	preset_export breeze-dark
	"$UNIT" apply
	[ "$(kcfg kdeglobals Icons Theme)" = "breeze-dark" ]
	[ ! -d "$user_icons" ]
}

@test "restore brings back an unset theme (KDE's default) exactly" {
	saved=$("$UNIT" current)
	[ "$saved" = "theme=" ]
	preset_export mocha
	"$UNIT" apply
	printf '%s\n' "$saved" | "$UNIT" restore
	[ "$(kcfg kdeglobals Icons Theme)" = "" ]
}

@test "restore without a theme= line is an error" {
	run "$UNIT" restore </dev/null
	[ "$status" -eq 65 ]
}

@test "kome deps names the Papirus package" {
	rm -rf "$XDG_DATA_DIRS/icons/Papirus-Dark"
	run "$KOME_ROOT/bin/kome" deps mocha
	[[ "$output" == *"papirus-icon-theme"* ]] || [[ "$output" == *"Papirus-Dark"* ]]
}
