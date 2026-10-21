# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Helpers shared by every kome program. Sourced, never executed.
# The sourcing script must set KOME_ROOT (the install root) first.

KOME_PROG=${KOME_PROG:-kome}
KOME_STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/kome

# Exit codes, sysexits(3) style (documented in kome(1)).
EX_OK=0
EX_USAGE=64       # wrong usage: unknown command, option or preset
EX_DATAERR=65     # a malformed preset, palette, style, template or state
EX_NOINPUT=66     # no such snapshot
EX_UNAVAILABLE=69 # something needed is missing, or a tool failed
EX_SOFTWARE=70    # a unit failed while applying or restoring
EX_TEMPFAIL=75    # another kome is busy

# `unit check` exit codes (the unit contract, CLAUDE.md §6).
CHECK_READY=0
CHECK_ABSENT=1   # an integration's app is not installed (may print app:<name>)
CHECK_MISSING=2  # a required ingredient is missing (names on stdout)
CHECK_ERROR=3    # cannot run here (reason on stderr)
CHECK_OPTIONAL=4 # an optional ingredient is missing (names on stdout)

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

# need_tools <tool>... — for a unit's check: stop with CHECK_ERROR, and say
# why, if a tool it needs is not installed.
need_tools() {
	for _tool in "$@"; do
		if ! command -v "$_tool" >/dev/null 2>&1; then
			err "$_tool not found: this needs KDE Plasma 6"
			hint "run 'kome doctor' on a Plasma 6 session"
			exit "$CHECK_ERROR"
		fi
	done
}

# data_dirs — the user's data dir, then the system ones, one per line.
data_dirs() {
	printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
	printf '%s\n' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' '\n'
}

# icon_dirs — where icon and cursor themes live: ~/.icons, then each data dir.
icon_dirs() {
	printf '%s\n' "$HOME/.icons"
	data_dirs | sed 's|$|/icons|'
}

# first_path <test> <relative path>
# Read directories on stdin; print the first <dir>/<relative path> that
# passes `test <test>` (-f, -d…). Return 1 if none does.
first_path() {
	while IFS= read -r _dir; do
		if [ -n "$_dir" ] && test "$1" "$_dir/$2"; then
			printf '%s\n' "$_dir/$2"
			return 0
		fi
	done
	return 1
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
# Manifest lines are "path <absolute path>", or for a line kome added to a
# user's file, "line<TAB><absolute path><TAB><the line>".
manifest_add() {
	mkdir -p "$KOME_STATE_DIR"
	grep -qxF "path $1" "$KOME_STATE_DIR/manifest" 2>/dev/null ||
		printf 'path %s\n' "$1" >>"$KOME_STATE_DIR/manifest"
}

# manifest_add_line <file> <line>
# Record a line kome added to a user's file, so `kome purge` removes it.
manifest_add_line() {
	mkdir -p "$KOME_STATE_DIR"
	_entry=$(printf 'line\t%s\t%s' "$1" "$2")
	grep -qxF "$_entry" "$KOME_STATE_DIR/manifest" 2>/dev/null ||
		printf '%s\n' "$_entry" >>"$KOME_STATE_DIR/manifest"
}
