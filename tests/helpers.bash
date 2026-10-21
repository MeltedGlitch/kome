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
	mkdir -p "$XDG_DATA_DIRS/color-schemes"
	touch "$XDG_DATA_DIRS/color-schemes/BreezeDark.colors" \
		"$XDG_DATA_DIRS/color-schemes/BreezeLight.colors"

	export FAKECFG="$BATS_TEST_TMPDIR/kconfig"
	export STATE="$FAKECFG/kdeglobals/General/ColorScheme"
	export LOG="$BATS_TEST_TMPDIR/applied" DBUSLOG="$BATS_TEST_TMPDIR/dbus"
	export FONTS="$BATS_TEST_TMPDIR/fonts"
	mkdir -p "$(dirname "$STATE")"
	printf 'BreezeDark\n' >"$STATE"
	printf '%s\n' Inter 'JetBrains Mono' 'Noto Sans' Hack >"$FONTS"

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
