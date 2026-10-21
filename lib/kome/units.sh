# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Units and snapshots. Source common.sh and preset.sh first.

KOME_UNITS_DIR=$KOME_ROOT/libexec/kome/units
KOME_STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/kome
KOME_SNAP_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/kome/snapshots
KOME_CONF=$KOME_USER_DIR/kome.conf

# units_all
# Print every unit directory, in run order (NN-name sorts by NN).
units_all() {
	for _u in "$KOME_UNITS_DIR"/*/; do
		if [ -x "${_u}unit" ]; then
			printf '%s\n' "${_u%/}"
		fi
	done
}

# unit_name <dir> — "…/10-colors" → "colors".
unit_name() {
	_n=${1##*/}
	printf '%s\n' "${_n#*-}"
}

# unit_enabled <name>
# A unit is on unless kome.conf says "<name>=off" in [Units].
unit_enabled() {
	[ -f "$KOME_CONF" ] || return 0
	_v=$(ini_get "$KOME_CONF" Units "$1") || return 0
	case $_v in
	on) return 0 ;;
	off) return 1 ;;
	*)
		warn "$KOME_CONF: [Units] $1=$_v should be 'on' or 'off'; treating it as on"
		return 0
		;;
	esac
}

# unit_check <dir>
# Run the unit's check. Sets $check_status and $check_out (its stdout).
unit_check() {
	check_status=0
	check_out=$("$1/unit" check) || check_status=$?
}

# snapshot_take <name>
# Save every unit's current state (enabled or not) as snapshots/<name>/<unit>,
# plus the active preset in snapshots/<name>/.preset. Atomic: the old snapshot
# is replaced only once the new one is complete.
snapshot_take() {
	mkdir -p "$KOME_SNAP_DIR"
	_tmp=$KOME_SNAP_DIR/.$1.tmp
	rm -rf "$_tmp"
	mkdir "$_tmp"
	for _u in $(units_all); do
		unit_check "$_u"
		case $check_status in
		1 | 3) continue ;; # not installed / cannot run here: nothing to save
		esac
		"$_u/unit" current >"$_tmp/$(unit_name "$_u")" || {
			rm -rf "$_tmp"
			err "could not read the current state of '$(unit_name "$_u")'"
			return 70
		}
	done
	cat "$KOME_STATE_DIR/active" >"$_tmp/.preset" 2>/dev/null || : >"$_tmp/.preset"
	rm -rf "${KOME_SNAP_DIR:?}/${1:?}"
	mv "$_tmp" "$KOME_SNAP_DIR/$1"
}

# snapshot_restore <name>
# Feed each saved state back to its unit's restore, in run order.
snapshot_restore() {
	for _u in $(units_all); do
		_f=$KOME_SNAP_DIR/$1/$(unit_name "$_u")
		[ -f "$_f" ] || continue
		"$_u/unit" restore <"$_f" || {
			err "could not restore '$(unit_name "$_u")'"
			return 70
		}
	done
}

# lock_take — allow only one kome changing the desktop at a time.
lock_take() {
	mkdir -p "$KOME_STATE_DIR"
	if ! mkdir "$KOME_STATE_DIR/lock" 2>/dev/null; then
		die 75 "another kome is already changing the desktop" \
			"wait for it to finish; if none is running, remove $KOME_STATE_DIR/lock"
	fi
	trap 'rmdir "$KOME_STATE_DIR/lock" 2>/dev/null' EXIT
	trap 'exit 130' INT TERM
}
