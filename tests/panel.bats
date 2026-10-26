#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The panel unit, against a fake Plasma (helpers.bash): layouts go to Plasma
# as one script over D-Bus; current/restore work on Plasma's config files.

load helpers

setup() {
	host_path=$PATH
	fake_plasma
	KOME="$KOME_ROOT/bin/kome"
	UNIT="$KOME_ROOT/libexec/kome/units/60-panel/unit"
	. "$KOME_ROOT/lib/kome/common.sh"
	. "$KOME_ROOT/lib/kome/preset.sh"
	rc="$XDG_CONFIG_HOME/plasma-org.kde.plasma.desktop-appletsrc"
	shellrc="$XDG_CONFIG_HOME/plasmashellrc"
	mkdir -p "$XDG_CONFIG_HOME"
	# Plasma answers evaluateScript with $EVAL_REPLY.
	cat >"$stubs/dbus-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$DBUSLOG"
case "$*" in *evaluateScript*) printf '   %s\n' "${EVAL_REPLY-changed}" ;; esac
EOF
	chmod +x "$stubs/dbus-send"
	export SYSTEMD_SHELL=1
}

# A desktop (1), a panel (2) with a clock, its system tray (8), and the
# panel's view settings.
user_panels() {
	cat >"$rc" <<'EOF'
[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[Containments][1]
activityId=abc
formfactor=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][2]
formfactor=2
location=4
plugin=org.kde.panel

[Containments][2][Applets][3]
plugin=org.kde.plasma.digitalclock

[Containments][2][Applets][3][Configuration]
popupHeight=400
showSeconds=Always

[Containments][2][General]
AppletOrder=3

[Containments][8]
formfactor=2
plugin=org.kde.plasma.private.systemtray
EOF
	cat >"$shellrc" <<'EOF'
[PlasmaViews][Panel 2]
floating=1

[PlasmaViews][Panel 2][Defaults]
thickness=44

[Updates]
performed=foo.js
EOF
}

@test "panel is opt-in: a plain apply never touches the panels" {
	user_panels
	"$KOME" apply mocha
	! grep -q evaluateScript "$DBUSLOG"
}

@test "check: an empty layout is fine, an unknown one is an error with a hint" {
	run "$UNIT" check
	[ "$status" -eq 0 ]
	KOME_PANEL=dock run "$UNIT" check
	[ "$status" -eq 0 ]
	KOME_PANEL=nope run "$UNIT" check
	[ "$status" -eq 3 ]
	[[ "$output" == *"unknown panel layout: panel=nope"* ]]
	[[ "$output" == *"hint: use bar, dock or topbar"* ]]
}

@test "current prints the panels' and trays' sections, not the desktop's" {
	user_panels
	run "$UNIT" current
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "panels=2 8" ]
	[[ "$output" == *"a=[Containments][2][Applets][3][Configuration]"* ]]
	[[ "$output" == *"a=showSeconds=Always"* ]]
	[[ "$output" == *"a=[Containments][8]"* ]]
	[[ "$output" == *"v=[PlasmaViews][Panel 2][Defaults]"* ]]
	[[ "$output" == *"v=thickness=44"* ]]
	[[ "$output" != *"folder"* ]]
	[[ "$output" != *"Updates"* ]]
	[[ "$output" != *"popupHeight"* ]]
}

@test "current with no panels at all" {
	run "$UNIT" current
	[ "$output" = "panels=none" ]
}

@test "apply sends the layout and panel.js to Plasma, then restarts the shell" {
	KOME_PANEL=dock run "$UNIT" apply
	[ "$status" -eq 0 ]
	grep -q 'org.kde.PlasmaShell.evaluateScript string:// kome panel layout "dock"' "$DBUSLOG"
	grep -q 'lengthMode: "fit"' "$DBUSLOG"
	grep -q 'print("changed")' "$DBUSLOG"
	grep -qx 'systemctl --user stop plasma-plasmashell.service' "$LOG"
	grep -qx 'systemctl --user start plasma-plasmashell.service' "$LOG"
}

@test "apply leaves the shell alone when the panels already match" {
	EVAL_REPLY=unchanged KOME_PANEL=dock run "$UNIT" apply
	[ "$status" -eq 0 ]
	! grep -q systemctl "$LOG"
}

@test "apply reports an error from Plasma's script and points to restore" {
	EVAL_REPLY="TypeError: bad" KOME_PANEL=bar run "$UNIT" apply
	[ "$status" -ne 0 ]
	[[ "$output" == *"the panel layout failed in Plasma: TypeError: bad"* ]]
	[[ "$output" == *"kome restore previous"* ]]
}

@test "apply needs a running Plasma shell" {
	unset SYSTEMD_SHELL
	KOME_PANEL=bar run "$UNIT" apply
	[ "$status" -eq 69 ]
	[[ "$output" == *"from your Plasma session"* ]]
}

@test "without systemd the shell is stopped with pkill and started again" {
	unset SYSTEMD_SHELL
	export SHELL_RUNNING=1
	KOME_PANEL=bar run "$UNIT" apply
	[ "$status" -eq 0 ]
	grep -qx 'pkill -x plasmashell' "$LOG"
	grep -qx 'plasmashell ' "$LOG"
}

@test "a user's own layout file overrides the shipped ones" {
	mkdir -p "$KOME_USER_DIR/templates/panel"
	printf '// mine\nvar layout = [];\n' >"$KOME_USER_DIR/templates/panel/mine.js"
	KOME_PANEL=mine run "$UNIT" check
	[ "$status" -eq 0 ]
	KOME_PANEL=mine "$UNIT" apply
	grep -q 'string:// mine' "$DBUSLOG"
}

@test "current | restore changes nothing and keeps the shell running" {
	user_panels
	cp "$rc" "$BATS_TEST_TMPDIR/rc.before"
	"$UNIT" current | "$UNIT" restore
	cmp "$rc" "$BATS_TEST_TMPDIR/rc.before"
	! grep -q systemctl "$LOG"
}

@test "restore puts the user's panels back in place of kome's, exactly" {
	user_panels
	"$UNIT" current >"$BATS_TEST_TMPDIR/saved"
	# What a kome layout leaves: panel 2 and tray 8 gone, a new panel 9.
	awk '/^\[Containments\]\[(2|8)\]/ { skip = 1; next } /^\[/ { skip = 0 } !skip' "$rc" >"$rc.new"
	printf '\n[Containments][9]\nformfactor=2\nplugin=org.kde.panel\n' >>"$rc.new"
	mv "$rc.new" "$rc"
	printf '[PlasmaViews][Panel 9]\nfloating=1\n\n[Updates]\nperformed=foo.js\n' >"$shellrc"
	"$UNIT" restore <"$BATS_TEST_TMPDIR/saved"
	! grep -qF '[Containments][9]' "$rc"
	grep -qx 'showSeconds=Always' "$rc"
	grep -qxF '[Containments][1]' "$rc"
	grep -qxF '[ActionPlugins][0]' "$rc"
	! grep -qF '[PlasmaViews][Panel 9]' "$shellrc"
	grep -qx 'thickness=44' "$shellrc"
	grep -qx 'performed=foo.js' "$shellrc"
	[ "$("$UNIT" current)" = "$(cat "$BATS_TEST_TMPDIR/saved")" ]
	grep -qx 'systemctl --user stop plasma-plasmashell.service' "$LOG"
	grep -qx 'systemctl --user start plasma-plasmashell.service' "$LOG"
}

@test "restore refuses when a saved panel's id now belongs to a desktop" {
	user_panels
	"$UNIT" current >"$BATS_TEST_TMPDIR/saved"
	sed -i 's/^plugin=org.kde.panel$/plugin=org.kde.plasma.folder/' "$rc"
	cp "$rc" "$BATS_TEST_TMPDIR/rc.before"
	run "$UNIT" restore <"$BATS_TEST_TMPDIR/saved"
	[ "$status" -eq 65 ]
	[[ "$output" == *"containment 2 is no longer a panel"* ]]
	cmp "$rc" "$BATS_TEST_TMPDIR/rc.before"
	! grep -q systemctl "$LOG"
}

@test "restore of panels=none removes kome's panels" {
	printf '[Containments][4]\nplugin=org.kde.panel\n\n[Containments][4][General]\nAppletOrder=\n' >"$rc"
	printf 'panels=none\n' | "$UNIT" restore
	! grep -q 'Containments' "$rc"
}

@test "turned on, kome apply builds the style's layout and restore original undoes it" {
	user_panels
	mkdir -p "$KOME_USER_DIR"
	printf '[Units]\npanel=on\n' >"$KOME_USER_DIR/kome.conf"
	"$KOME" apply mocha
	grep -q 'kome panel layout "bar"' "$DBUSLOG"
	grep -q '^a=showSeconds=Always' "$XDG_DATA_HOME/kome/snapshots/original/panel"
	# Plasma's new panel, as the restart would have written it.
	sed -i 's/^showSeconds=Always$/showSeconds=Never/' "$rc"
	"$KOME" restore original
	grep -qx 'showSeconds=Always' "$rc"
}

@test "the layout scripts are valid JavaScript" {
	node=$(PATH=$host_path command -v node) || skip "node is not installed"
	d="$KOME_ROOT/libexec/kome/units/60-panel"
	for l in bar dock topbar; do
		cat "$d/$l.js" "$d/panel.js" >"$BATS_TEST_TMPDIR/$l.js"
		"$node" --check "$BATS_TEST_TMPDIR/$l.js"
	done
}
