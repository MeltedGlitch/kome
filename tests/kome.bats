#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Dispatcher behaviour.

setup() {
	KOME="$BATS_TEST_DIRNAME/../bin/kome"
}

@test "--version prints the name and version" {
	run "$KOME" --version
	[ "$status" -eq 0 ]
	[[ "$output" == "kome "* ]]
}

@test "--help prints usage and exits 0" {
	run "$KOME" --help
	[ "$status" -eq 0 ]
	[[ "$output" == "usage: kome"* ]]
}

@test "no arguments is a usage error" {
	run "$KOME"
	[ "$status" -eq 64 ]
}

@test "unknown command fails with a hint" {
	run "$KOME" nope
	[ "$status" -eq 64 ]
	[[ "$output" == *"unknown command: nope"* ]]
	[[ "$output" == *"hint: "* ]]
}

@test "unknown option fails with a hint" {
	run "$KOME" --nope
	[ "$status" -eq 64 ]
	[[ "$output" == *"hint: "* ]]
}

@test "a command name cannot be a path" {
	run "$KOME" ../bin/kome
	[ "$status" -eq 64 ]
}
