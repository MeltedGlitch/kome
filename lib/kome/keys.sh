# shellcheck shell=sh
# shellcheck disable=SC2154 # $KEYS is set by the unit that sources this file
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Units whose state is a fixed set of KDE config keys. Source common.sh
# first, then set KEYS, one key per line:
#
#   <state name>:<config file>:<group>:<key>
#
# e.g. "blur:kwinrc:Plugins:blurEnabled". The state (current/restore) is
# one "name=value" line per key, the raw value — empty when the key is not
# set, which restore turns back into a deleted key (KDE's default).

# key_set <state name> <value> — write the key, or delete it when empty.
key_set() {
	_entry=$(printf '%s\n' "$KEYS" | grep "^$1:")
	_rest=${_entry#*:}
	_file=${_rest%%:*}
	_rest=${_rest#*:}
	_group=${_rest%%:*}
	_key=${_rest#*:}
	if [ -z "$2" ]; then
		kwriteconfig6 --notify --file "$_file" --group "$_group" --key "$_key" --delete
	else
		kwriteconfig6 --notify --file "$_file" --group "$_group" --key "$_key" "$2"
	fi
}

# keys_current — print every key's raw value as name=value.
keys_current() {
	printf '%s\n' "$KEYS" | while IFS=: read -r _name _file _group _key; do
		printf '%s=%s\n' "$_name" "$(kreadconfig6 --file "$_file" --group "$_group" --key "$_key")"
	done
}

# keys_restore — set every key from the name=value lines on stdin. Keys
# missing from the input are left alone.
keys_restore() {
	_saved=$(cat)
	_first=$(printf '%s\n' "$KEYS" | head -n 1)
	printf '%s\n' "$_saved" | grep -q "^${_first%%:*}=" ||
		die "$EX_DATAERR" "no '${_first%%:*}=' line on stdin" "pipe in the output of 'unit current'"
	printf '%s\n' "$KEYS" | while IFS=: read -r _name _rest; do
		_line=$(printf '%s\n' "$_saved" | grep "^$_name=" | tail -n 1) || continue
		key_set "$_name" "${_line#*=}"
	done
}

# kwin_reconfigure — ask KWin to reload its settings.
kwin_reconfigure() {
	dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure 2>/dev/null || :
}
