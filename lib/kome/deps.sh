# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Turning ingredients ("font:Inter", "app:kitty"…) into install commands.
# Source common.sh and preset.sh first. kome prints these commands and
# never runs them; distro knowledge lives only in the data table.

KOME_DEPS_TABLE=$KOME_DATA_DIR/deps/packages.ini

# The first package manager found wins.
KOME_PM=
for _pm in dnf zypper pacman apt; do
	if command -v "$_pm" >/dev/null 2>&1; then
		KOME_PM=$_pm
		break
	fi
done
case $KOME_PM in
dnf) KOME_INSTALL="sudo dnf install" ;;
zypper) KOME_INSTALL="sudo zypper install" ;;
pacman) KOME_INSTALL="sudo pacman -S --needed" ;;
apt) KOME_INSTALL="sudo apt install" ;;
*) KOME_INSTALL= ;;
esac

# deps_commands <ingredients, one per line>
# Print the commands that install them: one package-manager command for
# everything packaged, then a per-user command for each `install=` entry.
# What has neither is explained on stderr.
deps_commands() {
	printf '%s\n' "$1" | {
		_pkgs=
		while IFS= read -r _ing; do
			[ -n "$_ing" ] || continue
			_pkg=
			[ -z "$KOME_PM" ] || _pkg=$(ini_get "$KOME_DEPS_TABLE" "$_ing" "$KOME_PM" 2>/dev/null) || _pkg=
			if [ -n "$_pkg" ]; then
				_pkgs="$_pkgs $_pkg"
			elif _cmd=$(ini_get "$KOME_DEPS_TABLE" "$_ing" install 2>/dev/null); then
				printf '%s\n' "$_cmd"
			elif _url=$(ini_get "$KOME_DEPS_TABLE" "$_ing" url 2>/dev/null); then
				printf 'kome: %s is not packaged for %s; get it from %s\n' "${_ing#*:}" "${KOME_PM:-your system}" "$_url" >&2
			else
				printf 'kome: install %s with your package manager\n' "${_ing#*:}" >&2
			fi
		done
		[ -z "$_pkgs" ] || printf '%s%s\n' "$KOME_INSTALL" "$_pkgs"
	}
}
