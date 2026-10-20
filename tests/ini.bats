#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# INI reader (lib/kome/ini.awk and the ini_* helpers).

setup() {
	KOME_ROOT="$BATS_TEST_DIRNAME/.."
	INI="$KOME_ROOT/lib/kome/ini.awk"
	. "$KOME_ROOT/lib/kome/common.sh"
	f="$BATS_TEST_TMPDIR/test.ini"
}

@test "dump prints every entry as Section.key=value" {
	printf '[Preset]\nName=Mocha\n[Palette]\nbase=#1e1e2e\n' >"$f"
	run ini_dump "$f"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "Preset.Name=Mocha" ]
	[ "${lines[1]}" = "Palette.base=#1e1e2e" ]
}

@test "comments and blank lines are ignored" {
	printf '# comment\n; other comment\n\n[A]\n  # indented comment\nk=v\n' >"$f"
	run ini_dump "$f"
	[ "$status" -eq 0 ]
	[ "$output" = "A.k=v" ]
}

@test "whitespace around keys, values and section names is trimmed" {
	printf '[ A ]\n  key  =  some value  \n' >"$f"
	run ini_dump "$f"
	[ "$output" = "A.key=some value" ]
}

@test "values keep '#' and later '=' verbatim" {
	printf '[A]\ncolor=#b4befe\nexpr=a=b\n' >"$f"
	run ini_get "$f" A expr
	[ "$output" = "a=b" ]
	run ini_get "$f" A color
	[ "$output" = "#b4befe" ]
}

@test "an empty value is allowed" {
	printf '[A]\nk=\n' >"$f"
	run ini_get "$f" A k
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "CRLF line endings are handled" {
	printf '[A]\r\nk=v\r\n' >"$f"
	run ini_get "$f" A k
	[ "$output" = "v" ]
}

@test "get: the last duplicate wins" {
	printf '[A]\nk=1\nk=2\n' >"$f"
	run ini_get "$f" A k
	[ "$output" = "2" ]
}

@test "get: same key in another section is not confused" {
	printf '[A]\nk=a\n[B]\nk=b\n' >"$f"
	run ini_get "$f" B k
	[ "$output" = "b" ]
}

@test "get: a missing key returns 1 and prints nothing" {
	printf '[A]\nk=v\n' >"$f"
	run ini_get "$f" A nope
	[ "$status" -eq 1 ]
	[ "$output" = "" ]
}

@test "a key outside any section is an error with file:line" {
	printf 'k=v\n' >"$f"
	run ini_dump "$f"
	[ "$status" -eq 65 ]
	[[ "$output" == *"test.ini:1: key outside a section"* ]]
}

@test "a line that is neither key=value nor [Section] is an error" {
	printf '[A]\nk=v\ngarbage\n' >"$f"
	run ini_get "$f" A k
	[ "$status" -eq 65 ]
	[[ "$output" == *"test.ini:3:"* ]]
}

@test "an empty section name is an error" {
	printf '[ ]\nk=v\n' >"$f"
	run ini_dump "$f"
	[ "$status" -eq 65 ]
}

@test "an empty key is an error" {
	printf '[A]\n=v\n' >"$f"
	run ini_dump "$f"
	[ "$status" -eq 65 ]
}

@test "line numbers restart for each file" {
	g="$BATS_TEST_TMPDIR/second.ini"
	printf '[A]\nk=v\n' >"$f"
	printf 'bad\n' >"$g"
	run ini_dump "$f" "$g"
	[ "$status" -eq 65 ]
	[[ "$output" == *"second.ini:1:"* ]]
}
