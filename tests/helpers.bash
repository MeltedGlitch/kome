# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared test setup: a fake Plasma. Every XDG dir points into the test's
# temp dir and Plasma's tools are stubs on PATH, so tests never touch the
# real desktop.
#
#   $FAKECFG  fake KConfig: one file per key, $FAKECFG/<file>/<group…>/<key>
#   $STATE    the active colour scheme (kdeglobals General ColorScheme)
#   $LOG      every scheme plasma-apply-colorscheme was asked to apply
#   $FONTS    installed font families, one per line (read by fc-list)
#   $DBUSLOG  every dbus-send call
#   FAIL_APPLY=1 makes plasma-apply-colorscheme fail

fake_plasma() {
	KOME_ROOT="$BATS_TEST_DIRNAME/.."
	export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
	export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
	export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
	export XDG_DATA_DIRS="$BATS_TEST_TMPDIR/system"
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME" "$XDG_DATA_DIRS/color-schemes" "$XDG_DATA_DIRS/icons/breeze_cursors/cursors"
	touch "$XDG_DATA_DIRS/color-schemes/BreezeDark.colors" \
		"$XDG_DATA_DIRS/color-schemes/BreezeLight.colors"

	export FAKECFG="$BATS_TEST_TMPDIR/kconfig"
	export STATE="$FAKECFG/kdeglobals/General/ColorScheme"
	export LOG="$BATS_TEST_TMPDIR/applied" DBUSLOG="$BATS_TEST_TMPDIR/dbus"
	export FONTS="$BATS_TEST_TMPDIR/fonts"
	mkdir -p "$(dirname "$STATE")"
	printf 'BreezeDark\n' >"$STATE"
	printf '%s\n' Inter 'JetBrains Mono' 'Noto Sans' Hack >"$FONTS"

	fake_icon_themes

	stubs="$BATS_TEST_TMPDIR/stubs"
	mkdir -p "$stubs"
	cat >"$stubs/kreadconfig6" <<'EOF'
#!/bin/sh
path= key= def=
while [ $# -gt 0 ]; do
	case $1 in
	--file) path=$2; shift ;;
	--group) path=$path/$2; shift ;;
	--key) key=$2; shift ;;
	--default) def=$2; shift ;;
	esac
	shift
done
if [ -f "$FAKECFG/$path/$key" ]; then cat "$FAKECFG/$path/$key"; else printf '%s\n' "$def"; fi
EOF
	cat >"$stubs/kwriteconfig6" <<'EOF'
#!/bin/sh
path= key= del= val=
while [ $# -gt 0 ]; do
	case $1 in
	--file) path=$2; shift ;;
	--group) path=$path/$2; shift ;;
	--key) key=$2; shift ;;
	--delete) del=1 ;;
	*) val=$1 ;;
	esac
	shift
done
mkdir -p "$FAKECFG/$path"
if [ -n "$del" ]; then rm -f "$FAKECFG/$path/$key"; else printf '%s\n' "$val" >"$FAKECFG/$path/$key"; fi
EOF
	cat >"$stubs/plasma-apply-colorscheme" <<'EOF'
#!/bin/sh
[ -z "${FAIL_APPLY-}" ] || exit 1
printf '%s\n' "$1" >>"$LOG"
printf '%s\n' "$1" >"$STATE"
EOF
	cat >"$stubs/plasma-apply-cursortheme" <<'EOF'
#!/bin/sh
mkdir -p "$FAKECFG/kcminputrc/Mouse"
printf '%s\n' "$1" >"$FAKECFG/kcminputrc/Mouse/cursorTheme"
printf 'cursor %s\n' "$1" >>"$LOG"
EOF
	cat >"$stubs/fc-list" <<'EOF'
#!/bin/sh
fam=$(printf '%s' "$1" | sed 's/\\//g')
grep -ix -- "$fam" "$FONTS" || :
EOF
	cat >"$stubs/dbus-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DBUSLOG"
EOF
	chmod +x "$stubs"/*
	export PATH="$stubs:$PATH"
}

# kcfg <file> <group> <key> — read the fake KConfig ("" if unset).
kcfg() {
	cat "$FAKECFG/$1/$2/$3" 2>/dev/null || :
}

# fake_unit <NN-name> <check-exit> [check-stdout] [unit.ini lines…]
# A unit in $KOME_UNITS_DIR that logs "name verb" to $UNITLOG.
fake_unit() {
	export KOME_UNITS_DIR="$BATS_TEST_TMPDIR/units" UNITLOG="$BATS_TEST_TMPDIR/units.log"
	_dir="$KOME_UNITS_DIR/$1"
	mkdir -p "$_dir"
	cat >"$_dir/unit" <<UNIT
#!/bin/sh
case \$1 in
check) printf '%s' '${3-}'; exit $2 ;;
current) echo "state=${1#*-}" ;;
*) echo "${1#*-} \$1" >>"\$UNITLOG" ;;
esac
UNIT
	chmod +x "$_dir/unit"
	shift 3 2>/dev/null || shift $#
	{
		echo '[Unit]'
		for _l in "$@"; do echo "$_l"; done
	} >"$_dir/unit.ini"
}

# fake_icon_themes — breeze, breeze-dark and a tiny Papirus family in the
# system icon dir. As in the real Papirus, the coloured folders are real
# files in Papirus and symlinks in Papirus-Dark, and folder.svg is a
# symlink to the default (blue) colour.
fake_icon_themes() {
	_icons="$XDG_DATA_DIRS/icons"
	for _t in breeze breeze-dark; do
		mkdir -p "$_icons/$_t"
		printf '[Icon Theme]\nName=%s\n' "$_t" >"$_icons/$_t/index.theme"
	done
	mkdir -p "$_icons/Papirus"
	printf '[Icon Theme]\nName=Papirus\nInherits=breeze,hicolor\n' >"$_icons/Papirus/index.theme"
	for _s in 22x22 48x48; do
		_p="$_icons/Papirus/$_s/places"
		mkdir -p "$_p"
		for _c in blue violet; do
			for _n in "folder-$_c" "folder-$_c-documents" "user-$_c-home"; do
				printf '<svg/>' >"$_p/$_n.svg"
			done
		done
		ln -s folder-blue.svg "$_p/folder.svg"
		ln -s folder-blue-documents.svg "$_p/folder-documents.svg"
		ln -s user-blue-home.svg "$_p/user-home.svg"
	done
	for _t in Papirus-Dark Papirus-Light; do
		mkdir -p "$_icons/$_t/22x22/places"
		printf '[Icon Theme]\nName=%s\nInherits=Papirus,breeze,hicolor\n' "$_t" >"$_icons/$_t/index.theme"
		ln -s ../../Papirus/22x22/places/folder-violet.svg "$_icons/$_t/22x22/places/folder-violet.svg"
	done
}
