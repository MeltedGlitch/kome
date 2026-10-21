# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Helpers shared by every kome program. Sourced, never executed.
# The sourcing script must set KOME_ROOT (the install root) first.

KOME_PROG=${KOME_PROG:-kome}
KOME_STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/kome

# Exit codes, sysexits(3) style.
EX_OK=0
EX_USAGE=64

# Messages always go to stderr; stdout is reserved for data.
err() { printf '%s: error: %s\n' "$KOME_PROG" "$*" >&2; }
warn() { printf '%s: warning: %s\n' "$KOME_PROG" "$*" >&2; }
hint() { printf 'hint: %s\n' "$*" >&2; }

# die <code> <message> [hint]
# Every error tells the user what to do next (principle 11).
die() {
	_code=$1
	err "$2"
	[ -n "${3-}" ] && hint "$3"
	exit "$_code"
}

# kome_awk <awk args>...
# Run awk with a fixed locale, so output never depends on the user's
# language (e.g. "0,5" instead of "0.5" for decimals).
kome_awk() {
	LC_ALL=C awk "$@"
}

# ini_get <file> <Section> <key>
# Print one value; return 1 if absent, 65 if the file is malformed.
ini_get() {
	kome_awk -v get="$2.$3" -f "$KOME_ROOT/lib/kome/ini.awk" "$1"
}

# ini_dump <file>...
# Print every entry as Section.key=value.
ini_dump() {
	kome_awk -f "$KOME_ROOT/lib/kome/ini.awk" "$@"
}

# template_fill <template>
# Print the template filled from the KOME_* environment (see template.awk).
template_fill() {
	kome_awk -f "$KOME_ROOT/lib/kome/color.awk" -f "$KOME_ROOT/lib/kome/template.awk" "$1"
}

# template_render <template> <dest>
# Fill the template into dest atomically: on any error dest is untouched.
template_render() {
	mkdir -p "$(dirname -- "$2")" || return
	if template_fill "$1" >"$2.kome-tmp"; then
		mv -f "$2.kome-tmp" "$2"
	else
		_rc=$?
		rm -f "$2.kome-tmp"
		return "$_rc"
	fi
}

# manifest_add <path>
# Record a file or directory kome created, so `kome purge` can remove it.
# Manifest lines are "path <absolute path>".
manifest_add() {
	mkdir -p "$KOME_STATE_DIR"
	grep -qxF "path $1" "$KOME_STATE_DIR/manifest" 2>/dev/null ||
		printf 'path %s\n' "$1" >>"$KOME_STATE_DIR/manifest"
}
