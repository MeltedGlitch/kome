# shellcheck shell=sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Plasma's shell (plasmashell: panels and desktop). With systemd it runs as
# the user unit plasma-plasmashell; without it (or when Plasma was not
# started by systemd) as a plain process. Source common.sh first.

# shell_mode — how plasmashell runs here: systemd, process or none.
shell_mode() {
	if command -v systemctl >/dev/null 2>&1 &&
		systemctl --user is-active --quiet plasma-plasmashell.service 2>/dev/null; then
		printf 'systemd\n'
	elif pgrep -x plasmashell >/dev/null 2>&1 && command -v plasmashell >/dev/null 2>&1; then
		printf 'process\n'
	else
		printf 'none\n'
	fi
}

# shell_restart — restart plasmashell; fails when it is not running.
shell_restart() {
	case $(shell_mode) in
	systemd) systemctl --user restart plasma-plasmashell.service ;;
	process) nohup plasmashell --replace >/dev/null 2>&1 & ;;
	*) return 1 ;;
	esac
}

# shell_stop <mode> — stop plasmashell and wait until it has written its
# config and exited (at most 10 seconds).
shell_stop() {
	case $1 in
	systemd) systemctl --user stop plasma-plasmashell.service ;;
	process)
		pkill -x plasmashell || :
		_n=0
		while pgrep -x plasmashell >/dev/null 2>&1; do
			_n=$((_n + 1))
			[ "$_n" -le 10 ] || return 1
			sleep 1
		done
		;;
	esac
}

# shell_start <mode> — start plasmashell again after shell_stop.
shell_start() {
	case $1 in
	systemd) systemctl --user start plasma-plasmashell.service ;;
	process) nohup plasmashell >/dev/null 2>&1 & ;;
	esac
}
