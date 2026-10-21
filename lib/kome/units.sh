# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Units and snapshots. Source common.sh and preset.sh first.

KOME_UNITS_DIR=${KOME_UNITS_DIR:-$KOME_ROOT/libexec/kome/units}
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

# unit_meta <dir> <key>
# Print one field of the unit's unit.ini ([Unit] section); return 1 if absent.
unit_meta() {
	ini_get "$1/unit.ini" Unit "$2" 2>/dev/null
}

# unit_label <dir> — what the unit gives, for messages ("window borders…").
unit_label() {
	unit_meta "$1" gives || unit_meta "$1" description || unit_name "$1"
}

# unit_enabled <dir>
# kome.conf's [Units] <name>=on|off wins; otherwise the unit's default=.
unit_enabled() {
	_name=$(unit_name "$1")
	_v=
	if [ -f "$KOME_CONF" ]; then
		_v=$(ini_get "$KOME_CONF" Units "$_name") || _v=
	fi
	[ -n "$_v" ] || _v=$(unit_meta "$1" default) || _v=on
	case $_v in
	on) return 0 ;;
	off) return 1 ;;
	*)
		warn "[Units] $_name=$_v should be 'on' or 'off'; treating it as on"
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

# snapshot_complete <name>
# Refresh, in an existing snapshot, every unit kome has never applied: its
# current state is still entirely the user's own, so it — not what it was at
# kome's first run — is what restoring must bring back. Covers units turned
# on later, units added by a kome upgrade, and changes the user made by hand
# meanwhile. A unit's entry freezes once kome applies it (units kome has
# applied are listed in $KOME_STATE_DIR/touched).
snapshot_complete() {
	for _u in $(units_all); do
		_n=$(unit_name "$_u")
		! grep -qx "$_n" "$KOME_STATE_DIR/touched" 2>/dev/null || continue
		unit_check "$_u"
		case $check_status in
		1 | 3) continue ;;
		esac
		"$_u/unit" current >"$KOME_SNAP_DIR/$1/.$_n.tmp" &&
			mv "$KOME_SNAP_DIR/$1/.$_n.tmp" "$KOME_SNAP_DIR/$1/$_n"
	done
}

# unit_touched <dir> — remember that kome has applied this unit.
unit_touched() {
	_n=$(unit_name "$1")
	grep -qx "$_n" "$KOME_STATE_DIR/touched" 2>/dev/null ||
		printf '%s\n' "$_n" >>"$KOME_STATE_DIR/touched"
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

# shell_state
# The current state of every unit Plasma's shell does not repaint on its own
# (takes_effect=shell, e.g. icons). Compared before and after a change to
# know whether the panel needs refreshing.
shell_state() {
	for _u in $(units_all); do
		if [ "$(unit_meta "$_u" takes_effect || :)" = shell ]; then
			"$_u/unit" current 2>/dev/null || :
		fi
	done
}

# panel_refresh
# Refresh Plasma's panel and desktop (plasmashell), which otherwise keeps
# showing old icons until hovered — a known Plasma bug. With systemd the
# shell runs as a user unit; without it (or when Plasma was not started by
# systemd) plasmashell replaces itself. kome.conf [General] RefreshPanel=off
# turns this into a hint only.
panel_refresh() {
	_how="systemctl --user restart plasma-plasmashell"
	if [ "$(ini_get "$KOME_CONF" General RefreshPanel 2>/dev/null || :)" = off ]; then
		printf 'kome: Plasma may keep showing old panel icons until you hover them\n' >&2
		hint "run '$_how' (or 'plasmashell --replace &') to refresh the panel"
		return 0
	fi
	if command -v systemctl >/dev/null 2>&1 &&
		systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
		systemctl --user restart plasma-plasmashell.service && return 0
	fi
	if pgrep -x plasmashell >/dev/null 2>&1 && command -v plasmashell >/dev/null 2>&1; then
		nohup plasmashell --replace >/dev/null 2>&1 &
		return 0
	fi
	printf 'kome: Plasma is not running here, so the panel was not refreshed\n' >&2
	hint "in your Plasma session, run '$_how' (or 'plasmashell --replace &')"
}
