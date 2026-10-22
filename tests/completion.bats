#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shell completions and `kome --commands`.

load helpers

setup() {
	fake_plasma
	export PATH="$KOME_ROOT/bin:$PATH"
}

# complete_bash <words…> — what bash would offer for the last word.
complete_bash() {
	source "$KOME_ROOT/completions/bash/kome"
	COMP_WORDS=("$@")
	COMP_CWORD=$(($# - 1))
	_kome
	printf '%s\n' "${COMPREPLY[@]}"
}

@test "kome --commands lists every subcommand, one per line" {
	run kome --commands
	[ "$status" -eq 0 ]
	for c in apply deps doctor list purge restore status; do
		printf '%s\n' "$output" | grep -qx "$c"
	done
}

@test "bash completes subcommands" {
	run complete_bash kome re
	[ "$output" = "restore" ]
	run complete_bash kome ""
	[[ "$output" == *apply* && "$output" == *doctor* && "$output" == *--version* ]]
}

@test "bash completes presets, the user's own included" {
	mkdir -p "$XDG_CONFIG_HOME/kome/presets"
	printf '[Preset]\nname=Mine\npalette=catppuccin-mocha\nstyle=soft\n' >"$XDG_CONFIG_HOME/kome/presets/mine.ini"
	run complete_bash kome apply m
	[[ "$output" == *mocha* && "$output" == *mine* ]]
	run complete_bash kome deps br
	[[ "$output" == *breeze* && "$output" == *breeze-dark* ]]
}

@test "bash completes options and snapshot names" {
	run complete_bash kome apply --pa
	[ "$output" = "$(printf -- '--partial\n--palette')" ]
	run complete_bash kome apply --palette no
	[ "$output" = "nord" ]
	run complete_bash kome restore ""
	[ "$output" = "$(printf 'original\nprevious\n--help')" ]
}

@test "zsh and fish completion files load" {
	if command -v zsh >/dev/null; then zsh -n "$KOME_ROOT/completions/zsh/_kome"; fi
	if command -v fish >/dev/null; then fish -n "$KOME_ROOT/completions/fish/kome.fish"; fi
}
