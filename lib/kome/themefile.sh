# shellcheck shell=sh
# shellcheck disable=SC2154 # the tf_* variables are set by the unit that sources this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Integrations whose app reads kome's colours from one theme file that the
# user's config includes with one line (kitty, Ghostty…). Source common.sh
# and preset.sh first, set these, then call `themefile_main "$@"`:
#
#   tf_app       the app's command and process name (e.g. kitty)
#   tf_title     its name in messages (e.g. Ghostty)
#   tf_conf      the user's config file the include line goes into
#   tf_theme     kome's theme file (absolute path)
#   tf_include   the include line (e.g. "include kome-theme.conf")
#   tf_template  the template's file name in the unit's directory
#   tf_signal    the signal that makes running instances reload (e.g. USR1);
#                empty: the app reloads by itself or on restart
#
# Optional, for apps where the "include" is choosing a theme inside the app
# rather than a config line (VS Code, btop…): leave tf_include empty and set
#
#   tf_selected  "<file>:<regex>": the app uses kome's theme when a line of
#                <file> matches the extended regex
#   tf_choose    how to choose it, for the notice (e.g. "press Ctrl+K Ctrl+T…")
#
# and, when the app needs more than the theme file, define functions
# tf_on_write (after writing the theme) and tf_on_remove (after removing it).
# A unit whose app is not always a command on PATH (a Flatpak) defines
# tf_present, which succeeds when the app is installed.
#
# apply writes the theme file and reloads the app; it never edits the user's
# config. check announces the missing include line as a fix, and
# `kome doctor --fix` runs `unit fix`, which appends it and records it in
# the manifest so `kome purge` takes it out again.

tf_included() {
	[ -n "${tf_include-}" ] || return 0
	grep -qxF "$tf_include" "$tf_conf" 2>/dev/null
}

tf_reload() {
	[ -z "${tf_signal-}" ] || pkill "-$tf_signal" -x "$tf_app" 2>/dev/null || :
}

# tf_hook <name> — run the unit's hook function if it defines one.
tf_hook() {
	if command -v "$1" >/dev/null 2>&1; then
		"$1"
	fi
}

# tf_chosen — does the app use kome's theme (when that is the user's choice)?
tf_chosen() {
	[ -n "${tf_selected-}" ] || return 0
	grep -qE "${tf_selected#*:}" "${tf_selected%%:*}" 2>/dev/null
}

tf_installed() {
	if command -v tf_present >/dev/null 2>&1; then
		tf_present
	else
		command -v "$tf_app" >/dev/null 2>&1
	fi
}

tf_check() {
	if ! tf_installed; then
		printf 'app:%s\n' "$tf_app"
		exit "$CHECK_ABSENT"
	fi
	if ! tf_included; then
		printf 'fix:add "%s" to %s\n' "$tf_include" "$tf_conf"
	fi
	exit "$CHECK_READY"
}

tf_apply() {
	_template=$(template_find "$tf_app" "$tf_template")
	template_render "$_template" "$tf_theme" ||
		die "$EX_DATAERR" "could not generate the $tf_title theme from $_template"
	manifest_add "$tf_theme"
	tf_hook tf_on_write
	tf_reload
	if ! tf_included; then
		printf 'kome: %s will use the new colours once %s includes them\n' "$tf_title" "${tf_conf##*/}" >&2
		hint "run 'kome doctor --fix' to add that one line"
	elif ! tf_chosen; then
		printf "kome: %s will use the new colours once you choose its 'kome' theme\n" "$tf_title" >&2
		hint "$tf_choose"
	fi
}

# The state is the theme file itself: "theme=none", or "theme=kome" followed
# by its lines as "line=…", so restore can write it back exactly.
tf_current() {
	if [ -f "$tf_theme" ]; then
		printf 'theme=kome\n'
		sed 's/^/line=/' "$tf_theme"
	else
		printf 'theme=none\n'
	fi
}

tf_restore() {
	_saved=$(cat)
	case $_saved in
	theme=none*)
		rm -f "$tf_theme"
		tf_hook tf_on_remove
		;;
	theme=kome*)
		mkdir -p "$(dirname -- "$tf_theme")"
		printf '%s\n' "$_saved" | sed -n 's/^line=//p' >"$tf_theme.kome-tmp"
		mv -f "$tf_theme.kome-tmp" "$tf_theme"
		tf_hook tf_on_write
		;;
	*) die "$EX_DATAERR" "no 'theme=' line on stdin" "pipe in the output of 'unit current'" ;;
	esac
	tf_reload
}

tf_fix() {
	tf_included && return 0
	mkdir -p "$(dirname -- "$tf_conf")"
	# Keep the user's file intact: only append, on a line of its own.
	if [ -s "$tf_conf" ] && [ -n "$(tail -c 1 "$tf_conf")" ]; then
		printf '\n' >>"$tf_conf"
	fi
	printf '%s\n' "$tf_include" >>"$tf_conf"
	manifest_add_line "$tf_conf" "$tf_include"
	printf 'fixed: %s now includes %s\n' "$tf_conf" "${tf_theme##*/}"
	tf_reload
}

tf_usage() {
	cat <<EOF
usage: unit check | apply | current | restore | fix

  check    exit 0 if $tf_title is installed (1 and app:$tf_app: it is not); announces fixes
  apply    write ${tf_theme##*/} from the KOME_* colours, reload $tf_title
  current  print the theme file as theme=none|kome and line=… lines
  restore  write back the theme printed by 'current', read from stdin
EOF
	[ -z "${tf_include-}" ] ||
		printf '  fix      add "%s" to %s (recorded for kome purge)\n' "$tf_include" "${tf_conf##*/}"
}

themefile_main() {
	case ${1-} in
	check) tf_check ;;
	apply) tf_apply ;;
	current) tf_current ;;
	restore) tf_restore ;;
	fix) tf_fix ;;
	-h | --help) tf_usage ;;
	*)
		tf_usage >&2
		exit "$EX_USAGE"
		;;
	esac
}
