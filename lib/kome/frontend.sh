# shellcheck shell=sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The menus shared by kome's front ends (kome tui, kome gui). They are thin
# layers over the command line: every action runs a kome command and shows
# its output, so a front end can never behave differently from the CLI.
#
# Source common.sh first. A front end then defines how to draw:
#
#   ui_menu <title> <text> <default tag> <tag> <label>...
#       print the chosen tag; fail (non-zero) when the user cancels
#   ui_text <title> <file>   show a command's output (long text)
#   ui_note <text>           a short confirmation
#
# and calls frontend_main.

kome_cmd() {
	"$KOME_ROOT/bin/kome" "$@"
}

# fe_active — the active preset, or empty.
fe_active() {
	cat "${KOME_STATE_DIR:?}/active" 2>/dev/null || :
}

# fe_run <title> <command…> — run a kome command; on success say so briefly
# (or show its output, if any); on failure show everything it said, hints
# included. Returns the command's exit status.
fe_run() {
	_title=$1
	shift
	_out=$(mktemp)
	_rc=0
	kome_cmd "$@" >"$_out" 2>&1 </dev/null || _rc=$?
	if [ "$_rc" -eq 0 ] && [ ! -s "$_out" ]; then
		ui_note "$_title: done"
	else
		ui_text "$_title" "$_out"
	fi
	rm -f "$_out"
	return "$_rc"
}

# fe_apply — pick a preset (the active one preselected) and apply it. When
# something is missing, also show how to install it.
fe_apply() {
	_list=$(mktemp)
	kome_cmd list >"$_list" 2>/dev/null
	# One "tag label" pair per preset, for ui_menu.
	set --
	while IFS="$(printf '\t')" read -r _name _title; do
		set -- "$@" "$_name" "$_title"
	done <"$_list"
	rm -f "$_list"
	_pick=$(ui_menu "Apply a look" "Choose a look for the whole desktop:" "$(fe_active)" "$@") || return 0
	_rc=0
	fe_run "Apply $_pick" apply "$_pick" || _rc=$?
	if [ "$_rc" -eq "$EX_UNAVAILABLE" ]; then
		fe_run "What $_pick needs" deps "$_pick" || :
	fi
}

frontend_main() {
	while :; do
		_active=$(fe_active)
		_text="Active look: ${_active:-none (your own desktop)}"
		_choice=$(ui_menu "kome" "$_text" apply \
			apply "Apply a look" \
			previous "Undo the last change" \
			original "Back to my own desktop (before kome)" \
			status "What changed since the last apply" \
			doctor "Check this system" \
			quit "Quit") || return 0
		case $_choice in
		apply) fe_apply ;;
		previous) fe_run "Undo the last change" restore previous || : ;;
		original) fe_run "Back to my own desktop" restore original || : ;;
		status) fe_run "What changed" status -v || : ;;
		doctor) fe_run "Check this system" doctor || : ;;
		quit | '') return 0 ;;
		esac
	done
}
