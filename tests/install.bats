#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# make install and make uninstall, into a staging directory.

setup() {
	root="$BATS_TEST_DIRNAME/.."
	dest="$BATS_TEST_TMPDIR/stage"
}

@test "install puts kome in place and it runs from there" {
	make -s -C "$root" install DESTDIR="$dest" PREFIX=/usr/local
	[ -x "$dest/usr/local/bin/kome" ]
	[ -x "$dest/usr/local/libexec/kome/units/10-colors/unit" ]
	[ -f "$dest/usr/local/share/man/man1/kome.1" ]
	run env KOME_ROOT="$dest/usr/local" "$dest/usr/local/bin/kome" --version
	[ "$status" -eq 0 ]
}

@test "reinstalling removes files that are gone from the source, like a renamed unit" {
	make -s -C "$root" install DESTDIR="$dest" PREFIX=/usr/local
	mkdir -p "$dest/usr/local/libexec/kome/units/60-decoration"
	: >"$dest/usr/local/share/kome/presets/old.ini"
	make -s -C "$root" install DESTDIR="$dest" PREFIX=/usr/local
	[ ! -e "$dest/usr/local/libexec/kome/units/60-decoration" ]
	[ ! -e "$dest/usr/local/share/kome/presets/old.ini" ]
	[ -d "$dest/usr/local/libexec/kome/units/05-decoration" ]
}

@test "uninstall removes everything install put there" {
	make -s -C "$root" install DESTDIR="$dest" PREFIX=/usr/local
	make -s -C "$root" uninstall DESTDIR="$dest" PREFIX=/usr/local
	[ -z "$(find "$dest" -type f)" ]
}

@test "install adds a launcher entry that runs kome by its full path" {
	make -s -C "$root" install DESTDIR="$dest" PREFIX=/opt/kome
	f="$dest/opt/kome/share/applications/kome.desktop"
	grep -qx 'Exec=/opt/kome/bin/kome gui' "$f"
	if command -v desktop-file-validate >/dev/null; then desktop-file-validate "$f"; fi
}
