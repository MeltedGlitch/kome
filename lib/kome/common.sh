# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Helpers shared by every kome program. Sourced, never executed.

KOME_PROG=${KOME_PROG:-kome}

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
