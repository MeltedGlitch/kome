#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The rendering unit (opt-in), against a fake Plasma (helpers.bash).

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	UNIT="$KOME_ROOT/libexec/kome/units/50-rendering/unit"
	fc="$XDG_CONFIG_HOME/fontconfig/conf.d/90-kome-rendering.conf"
	env="$XDG_CONFIG_HOME/plasma-workspace/env/kome-rendering.sh"
}

turn_on() {
	mkdir -p "$XDG_CONFIG_HOME/kome"
	printf '[Units]\nrendering=on\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
}

@test "it is opt-in: a plain apply does not touch font rendering" {
	"$KOME" apply mocha
	[ ! -e "$fc" ]
	[ ! -e "$env" ]
	[ "$(kcfg kdeglobals General XftHintStyle)" = "" ]
}

@test "turned on, apply writes fontconfig, the login script and KDE's keys" {
	turn_on
	run "$KOME" apply mocha
	[ "$status" -eq 0 ]
	grep -q '<const>hintslight</const>' "$fc"
	grep -q '<const>none</const>' "$fc"
	grep -qx 'export FREETYPE_PROPERTIES="cff:no-stem-darkening=0 autofitter:no-stem-darkening=0"' "$env"
	[ "$(kcfg kdeglobals General XftAntialias)" = "true" ]
	[ "$(kcfg kdeglobals General XftHintStyle)" = "hintslight" ]
	[ "$(kcfg kdeglobals General XftSubPixel)" = "none" ]
	[[ "$output" == *"log out and back in to see crisper text"* ]]
}

@test "the login script is valid shell and only sets FREETYPE_PROPERTIES" {
	turn_on
	"$KOME" apply mocha
	sh -n "$env"
	(unset FREETYPE_PROPERTIES; . "$env"; [ -n "$FREETYPE_PROPERTIES" ])
}

@test "restore original removes the files and unsets the keys" {
	turn_on
	"$KOME" apply mocha
	"$KOME" restore original
	[ ! -e "$fc" ]
	[ ! -e "$env" ]
	[ "$(kcfg kdeglobals General XftHintStyle)" = "" ]
}

@test "restore brings back the user's own values exactly" {
	kwriteconfig6 --file kdeglobals --group General --key XftHintStyle hintfull
	saved=$("$UNIT" current)
	"$UNIT" apply
	printf '%s\n' "$saved" | "$UNIT" restore
	[ "$(kcfg kdeglobals General XftHintStyle)" = "hintfull" ]
	[ "$(kcfg kdeglobals General XftAntialias)" = "" ]
	[ "$("$UNIT" current)" = "$saved" ]
}

@test "turning it on later still saves the user's state in original" {
	"$KOME" apply mocha
	kwriteconfig6 --file kdeglobals --group General --key XftSubPixel rgb
	turn_on
	"$KOME" apply mocha
	"$KOME" restore original
	[ "$(kcfg kdeglobals General XftSubPixel)" = "rgb" ]
}

@test "purge deletes both files" {
	turn_on
	"$KOME" apply mocha
	"$KOME" purge --yes
	[ ! -e "$fc" ]
	[ ! -e "$env" ]
}

@test "a user's copy of the template wins" {
	turn_on
	mkdir -p "$XDG_CONFIG_HOME/kome/templates/rendering"
	printf 'export FREETYPE_PROPERTIES="cff:no-stem-darkening=1"\n' \
		>"$XDG_CONFIG_HOME/kome/templates/rendering/env.sh.in"
	"$KOME" apply mocha
	grep -qx 'export FREETYPE_PROPERTIES="cff:no-stem-darkening=1"' "$env"
}
