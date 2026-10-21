#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome deps, against a fake Plasma and a fake package manager.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	: >"$FONTS"
	# A PATH with only the basics plus one package manager of our choice.
	bin="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$bin"
	for t in sh awk cat dirname sed grep tr sort env basename mkdir; do
		ln -s "$(command -v "$t")" "$bin/$t"
	done
	for t in kreadconfig6 kwriteconfig6 plasma-apply-colorscheme plasma-apply-cursortheme fc-list dbus-send; do
		ln -s "$stubs/$t" "$bin/$t"
	done
}

with_pm() {
	printf '#!/bin/sh\n' >"$bin/$1"
	chmod +x "$bin/$1"
}

@test "prints the dnf command for missing fonts" {
	with_pm dnf
	PATH="$bin" run "$KOME" deps mocha
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "sudo dnf install rsms-inter-fonts jetbrains-mono-fonts" ]
}

@test "uses the names of the package manager it finds" {
	with_pm apt
	PATH="$bin" run "$KOME" deps mocha
	[ "${lines[0]}" = "sudo apt install fonts-inter fonts-jetbrains-mono" ]
	rm "$bin/apt"
	with_pm pacman
	PATH="$bin" run "$KOME" deps mocha
	[ "${lines[0]}" = "sudo pacman -S --needed inter-font ttf-jetbrains-mono" ]
}

@test "only what is missing is listed" {
	with_pm dnf
	printf 'Inter\n' >"$FONTS"
	PATH="$bin" run "$KOME" deps mocha
	[ "${lines[0]}" = "sudo dnf install jetbrains-mono-fonts" ]
}

@test "nothing missing says so, with a hint to apply" {
	with_pm dnf
	PATH="$bin" run "$KOME" deps breeze
	[ "$status" -eq 0 ]
	[[ "$output" == *"breeze has everything it needs"* ]]
	[[ "$output" == *"hint: run 'kome apply breeze'"* ]]
}

@test "without a known package manager, points to where to get each thing" {
	PATH="$bin" run "$KOME" deps mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"no known package manager"* ]]
	[[ "$output" == *"Inter is not packaged for your system; get it from https://rsms.me/inter/"* ]]
}

@test "an ingredient missing from the table still gets a message" {
	with_pm dnf
	mkdir -p "$XDG_CONFIG_HOME/kome/presets"
	printf '[Preset]\npalette=catppuccin-mocha\nstyle=soft\ncolor_scheme=Exotic\n' \
		>"$XDG_CONFIG_HOME/kome/presets/odd.ini"
	printf '%s\n' Inter 'JetBrains Mono' >"$FONTS"
	PATH="$bin" run "$KOME" deps odd
	[[ "$output" == *"install Exotic with your package manager"* ]]
}

@test "optional ingredients come after a '# optional' line" {
	with_pm dnf
	fake_unit 10-colors 0 "" default=on
	fake_unit 80-decoration 4 "font:Inter" default=on
	PATH="$bin" run "$KOME" deps mocha
	[ "$output" = "$(printf '# optional\nsudo dnf install rsms-inter-fonts')" ]
}

@test "deps rejects options and extra arguments" {
	run "$KOME" deps --nope
	[ "$status" -eq 64 ]
	run "$KOME" deps mocha latte
	[ "$status" -eq 64 ]
}
