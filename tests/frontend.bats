#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The front ends (kome tui, kome gui) against a fake Plasma (helpers.bash).
# Their dialogs are stubs that answer from a queue, one answer per call
# ("CANCEL" cancels), and log what they were asked to show.

load helpers

setup() {
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	ANSWERS="$BATS_TEST_TMPDIR/answers"
	SHOWN="$BATS_TEST_TMPDIR/shown"
	: >"$ANSWERS"
	: >"$SHOWN"
	export ANSWERS SHOWN
	# One stub for dialog, whiptail and kdialog. A menu takes the next
	# answer; a text box logs its title and file content.
	cat >"$stubs/ui-stub" <<'EOF'
#!/bin/sh
name=${0##*/}
title=
while [ $# -gt 0 ]; do
	case $1 in
	--title) title=$2; shift ;;
	--menu)
		printf '%s menu %s\n' "$name" "$title" >>"$SHOWN"
		answer=$(head -n 1 "$ANSWERS")
		sed -i 1d "$ANSWERS"
		[ -n "$answer" ] && [ "$answer" != CANCEL ] || exit 1
		# dialog and whiptail answer on stderr, kdialog on stdout.
		if [ "$name" = kdialog ]; then printf '%s\n' "$answer"; else printf '%s\n' "$answer" >&2; fi
		exit 0
		;;
	--textbox)
		printf '%s text %s\n' "$name" "$title" >>"$SHOWN"
		cat "$2" >>"$SHOWN"
		exit 0
		;;
	--msgbox | --passivepopup)
		printf '%s note %s\n' "$name" "$2" >>"$SHOWN"
		exit 0
		;;
	esac
	shift
done
EOF
	chmod +x "$stubs/ui-stub"
}

stub() { ln -sf "$stubs/ui-stub" "$stubs/$1"; }
answers() { printf '%s\n' "$@" >"$ANSWERS"; }

@test "tui (dialog): apply a look from the menus, the active one preselected" {
	stub dialog
	"$KOME" apply breeze 2>/dev/null
	answers apply mocha quit
	run "$KOME" tui
	[ "$status" -eq 0 ]
	[ "$(cat "$XDG_STATE_HOME/kome/active")" = mocha ]
	grep -q '^dialog menu Apply a look$' "$SHOWN"
	# What apply said (its notices) is shown, not lost.
	grep -q '^dialog text Apply mocha$' "$SHOWN"
}

@test "tui: the preset menu lists every preset and preselects the active one" {
	stub dialog
	"$KOME" apply latte 2>/dev/null
	printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"$BATS_TEST_TMPDIR/args"; exit 1\n' >"$stubs/dialog"
	chmod +x "$stubs/dialog"
	KOME_TUI=dialog run "$KOME" tui
	grep -qx -- '--default-item' "$BATS_TEST_TMPDIR/args"
	grep -qx 'Active look: latte' "$BATS_TEST_TMPDIR/args"
}

@test "tui (whiptail): undo the last change" {
	stub whiptail
	"$KOME" apply mocha 2>/dev/null
	"$KOME" apply latte 2>/dev/null
	answers previous quit
	run "$KOME" tui
	[ "$status" -eq 0 ]
	[ "$(cat "$XDG_STATE_HOME/kome/active")" = mocha ]
	grep -q '^whiptail ' "$SHOWN"
}

@test "tui: a look that needs something shows why, then how to install it" {
	stub dialog
	: >"$FONTS"
	printf '#!/bin/sh\n' >"$stubs/dnf"
	chmod +x "$stubs/dnf"
	answers apply mocha quit
	"$KOME" tui
	grep -q '^dialog text Apply mocha$' "$SHOWN"
	grep -q "kome deps mocha" "$SHOWN"
	grep -q '^dialog text What mocha needs$' "$SHOWN"
	grep -q 'sudo dnf install' "$SHOWN"
	[ ! -e "$XDG_STATE_HOME/kome/active" ]
}

@test "tui: cancelling the main menu quits; cancelling the preset menu goes back" {
	stub dialog
	answers apply CANCEL CANCEL
	run "$KOME" tui
	[ "$status" -eq 0 ]
	[ "$(grep -c '^dialog menu kome$' "$SHOWN")" -eq 2 ]
	[ ! -e "$XDG_STATE_HOME/kome/active" ]
}

@test "tui (plain): numbered menus on stderr, answers on stdin" {
	# Main menu: 1 apply; presets are listed in order, so pick by number.
	n=$("$KOME" list | cut -f1 | grep -nx mocha | cut -d: -f1)
	run sh -c "printf '1\n$n\nq\n' | KOME_TUI=plain '$KOME' tui"
	[ "$status" -eq 0 ]
	[[ "$output" == *" 1) Apply a look"* ]]
	[[ "$output" == *") Catppuccin Mocha"* ]]
	[ "$(cat "$XDG_STATE_HOME/kome/active")" = mocha ]
}

@test "tui (plain) is used when neither dialog nor whiptail is installed" {
	run sh -c "printf 'q\n' | '$KOME' tui"
	[ "$status" -eq 0 ]
	[[ "$output" == *"== kome =="* ]]
	[[ "$output" == *"Active look: none (your own desktop)"* ]]
}

@test "tui: check this system shows doctor's report" {
	stub dialog
	answers doctor quit
	"$KOME" tui
	grep -q '^dialog text Check this system$' "$SHOWN"
	grep -q '^ok  *colors' "$SHOWN"
}

@test "gui (kdialog): apply, then back to my own desktop" {
	stub kdialog
	answers apply mocha original quit
	run "$KOME" gui
	[ "$status" -eq 0 ]
	grep -q '^kdialog menu Apply a look$' "$SHOWN"
	grep -q '^kdialog \(note\|text\) Back to my own desktop' "$SHOWN"
	[ ! -e "$XDG_STATE_HOME/kome/active" ]
}

@test "gui without kdialog says what to install, or to use the tui" {
	run "$KOME" gui
	[ "$status" -eq 69 ]
	[[ "$output" == *"kdialog not found"* ]]
	[[ "$output" == *"kome tui"* ]]
}

@test "the front ends reject arguments and have --help" {
	run "$KOME" tui --nope
	[ "$status" -eq 64 ]
	run "$KOME" gui --help
	[ "$status" -eq 0 ]
	KOME_TUI=curses run "$KOME" tui
	[ "$status" -eq 64 ]
}

@test "a command that succeeds silently gets a short note" {
	stub kdialog
	"$KOME" apply breeze 2>/dev/null
	answers apply breeze quit
	"$KOME" gui
	grep -q '^kdialog note Apply breeze: done$' "$SHOWN"
}
