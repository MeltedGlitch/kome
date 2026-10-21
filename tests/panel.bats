#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Refreshing Plasma's panel after icon changes (a known Plasma bug keeps old
# icons until hovered), with and without systemd, against a fake Plasma.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
}

@test "with systemd, an icon change restarts the plasmashell unit" {
	export SYSTEMD_SHELL=1 SHELL_RUNNING=1
	"$KOME" apply mocha
	grep -qx 'systemctl --user restart plasma-plasmashell.service' "$LOG"
	! grep -q '^plasmashell' "$LOG"
}

@test "without systemd, plasmashell replaces itself" {
	export SHELL_RUNNING=1
	"$KOME" apply mocha
	grep -qx 'plasmashell --replace' "$LOG"
	! grep -q '^systemctl' "$LOG"
}

@test "re-applying the same look does not touch the panel" {
	export SYSTEMD_SHELL=1 SHELL_RUNNING=1
	"$KOME" apply mocha
	: >"$LOG"
	"$KOME" apply mocha
	! grep -q 'plasma-plasmashell\|^plasmashell' "$LOG"
}

@test "restore and purge refresh the panel too when icons change" {
	export SYSTEMD_SHELL=1 SHELL_RUNNING=1
	"$KOME" apply mocha
	: >"$LOG"
	"$KOME" restore original
	grep -q 'restart plasma-plasmashell' "$LOG"
	"$KOME" apply latte
	: >"$LOG"
	"$KOME" purge --yes
	grep -q 'restart plasma-plasmashell' "$LOG"
}

@test "outside a Plasma session, nothing is restarted and kome says what to run" {
	run "$KOME" apply mocha
	[ "$status" -eq 0 ]
	[[ "$output" == *"Plasma is not running here"* ]]
	[[ "$output" == *"systemctl --user restart plasma-plasmashell"* ]]
	! grep -q 'plasma-plasmashell\|^plasmashell' "$LOG"
}

@test "RefreshPanel=off in kome.conf only gives the hint" {
	export SYSTEMD_SHELL=1 SHELL_RUNNING=1
	mkdir -p "$XDG_CONFIG_HOME/kome"
	printf '[General]\nRefreshPanel=off\n' >"$XDG_CONFIG_HOME/kome/kome.conf"
	run "$KOME" apply mocha
	[[ "$output" == *"until you hover them"* ]]
	! grep -q 'plasma-plasmashell\|^plasmashell' "$LOG"
}
