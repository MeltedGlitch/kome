# shellcheck shell=sh
# shellcheck disable=SC2034 # variables here are used by the scripts that source this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Finding and resolving presets, palettes and styles. Source common.sh first.

# User files override shipped ones, the same way for every kind (principle 9).
KOME_USER_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/kome
KOME_DATA_DIR=$KOME_ROOT/share/kome

# data_find <kind> <name>
# Print the path of <kind>/<name>.ini (kind: presets, palettes, styles).
# Return 1 if there is none.
data_find() {
	case $2 in
	'' | .* | */*) return 1 ;;
	esac
	for _dir in "$KOME_USER_DIR" "$KOME_DATA_DIR"; do
		if [ -f "$_dir/$1/$2.ini" ]; then
			printf '%s\n' "$_dir/$1/$2.ini"
			return 0
		fi
	done
	return 1
}

# template_find <unit> <file>
# Print the template to use: the user's copy in templates/<unit>/ if there is
# one, else the unit's own.
template_find() {
	if [ -f "$KOME_USER_DIR/templates/$1/$2" ]; then
		printf '%s\n' "$KOME_USER_DIR/templates/$1/$2"
		return
	fi
	for _u in "$KOME_ROOT"/libexec/kome/units/*-"$1"; do
		printf '%s\n' "$_u/$2"
		return
	done
}

# data_list <kind>
# Print every available name of <kind>, sorted, once each.
data_list() {
	for _dir in "$KOME_USER_DIR" "$KOME_DATA_DIR"; do
		for _f in "$_dir/$1"/*.ini; do
			if [ -f "$_f" ]; then
				_f=${_f##*/}
				printf '%s\n' "${_f%.ini}"
			fi
		done
	done | sort -u
}

# preset_missing <palette|style> <name> <override> — report a missing palette
# or style: the user's own --palette/--style is a usage error, a preset file
# naming one that does not exist is a data error.
preset_missing() {
	if [ -n "$3" ]; then
		err "no $1 named '$2'"
		hint "run 'kome list ${1}s' to see them"
		return "$EX_USAGE"
	fi
	err "$_rfile: no $1 named '$2'"
	hint "run 'kome list ${1}s' to see them"
	return "$EX_DATAERR"
}

# preset_resolve <name>
# Print KOME_KEY=value lines for a preset: its palette, then its style, then
# the preset itself (later ones override). KOME_WITH_PALETTE / KOME_WITH_STYLE,
# when set, replace the preset's own palette / style (mixing looks). Errors go
# to stderr.
preset_resolve() {
	if ! _rfile=$(data_find presets "$1"); then
		err "no preset named '$1'"
		hint "run 'kome list' to see the presets"
		return "$EX_USAGE"
	fi
	_pname=${KOME_WITH_PALETTE:-$(ini_get "$_rfile" Preset palette)} || {
		err "$_rfile: missing 'palette=' in [Preset]"
		return "$EX_DATAERR"
	}
	_sname=${KOME_WITH_STYLE:-$(ini_get "$_rfile" Preset style)} || {
		err "$_rfile: missing 'style=' in [Preset]"
		return "$EX_DATAERR"
	}
	_pfile=$(data_find palettes "$_pname") || {
		preset_missing palette "$_pname" "${KOME_WITH_PALETTE-}"
		return
	}
	_sfile=$(data_find styles "$_sname") || {
		preset_missing style "$_sname" "${KOME_WITH_STYLE-}"
		return
	}
	_dump=$(ini_dump "$_pfile" "$_sfile" "$_rfile") || return
	printf '%s\n' "$_dump" | kome_awk \
		-v preset="$1" -v pfile="$_pfile" -v sfile="$_sfile" -v rfile="$_rfile" \
		-f "$KOME_ROOT/lib/kome/color.awk" -f "$KOME_ROOT/lib/kome/resolve.awk"
}

# preset_export <name>
# Resolve a preset and export its KOME_* variables into this shell.
preset_export() {
	_env=$(preset_resolve "$1") || return
	while IFS= read -r _line; do
		export "${_line?}"
	done <<EOF
$_env
EOF
}
