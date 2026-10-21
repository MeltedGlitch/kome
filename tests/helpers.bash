# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared test setup: a fake Plasma. Every XDG dir points into the test's
# temp dir and Plasma's tools are stubs on PATH, so tests never touch the
# real desktop.
#
#   $STATE  the "active colour scheme" (read by kreadconfig6)
#   $LOG    every scheme plasma-apply-colorscheme was asked to apply
#   FAIL_APPLY=1 makes plasma-apply-colorscheme fail

fake_plasma() {
	KOME_ROOT="$BATS_TEST_DIRNAME/.."
	export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
	export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
	export XDG_DATA_DIRS="$BATS_TEST_TMPDIR/system"
	mkdir -p "$XDG_DATA_DIRS/color-schemes"
	touch "$XDG_DATA_DIRS/color-schemes/BreezeDark.colors" \
		"$XDG_DATA_DIRS/color-schemes/BreezeLight.colors"

	stubs="$BATS_TEST_TMPDIR/stubs"
	mkdir -p "$stubs"
	export STATE="$BATS_TEST_TMPDIR/active-scheme" LOG="$BATS_TEST_TMPDIR/applied"
	printf 'BreezeDark\n' >"$STATE"
	cat >"$stubs/kreadconfig6" <<'EOF'
#!/bin/sh
cat "$STATE"
EOF
	cat >"$stubs/plasma-apply-colorscheme" <<'EOF'
#!/bin/sh
[ -z "${FAIL_APPLY-}" ] || exit 1
printf '%s\n' "$1" >>"$LOG"
printf '%s\n' "$1" >"$STATE"
EOF
	chmod +x "$stubs"/*
	export PATH="$stubs:$PATH"
}
