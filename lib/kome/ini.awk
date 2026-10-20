# SPDX-License-Identifier: GPL-3.0-or-later
#
# ini.awk — read kome's own INI files (presets, palettes, styles, kome.conf).
#
#   awk -f ini.awk FILE...                  print every entry as Section.key=value
#   awk -v get=Section.key -f ini.awk FILE  print one value (last one wins);
#                                           exit 1 if it is absent
#
# Values are taken verbatim after the first "=": there are no inline
# comments, so colours like "base=#1e1e2e" just work. A malformed line is an
# error (FILE:LINE on stderr, exit 65 = EX_DATAERR): a file is never half-read.

function trim(s) {
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s
}

function fail(msg) {
	printf "kome: error: %s:%d: %s\n", FILENAME, FNR, msg | "cat 1>&2"
	failed = 1
	exit 65
}

FNR == 1 { section = "" }

{
	sub(/\r$/, "")
	line = trim($0)
}

line == "" || line ~ /^[#;]/ { next }

line ~ /^\[.*\]$/ {
	section = trim(substr(line, 2, length(line) - 2))
	if (section == "")
		fail("empty section name")
	next
}

{
	eq = index(line, "=")
	if (eq == 0)
		fail("expected 'key=value' or '[Section]'")
	if (section == "")
		fail("key outside a section")
	key = trim(substr(line, 1, eq - 1))
	if (key == "")
		fail("empty key")
	id = section "." key
	val = trim(substr(line, eq + 1))
	if (get == "")
		print id "=" val
	else if (id == get) {
		value = val
		found = 1
	}
}

END {
	if (failed)
		exit 65
	if (get != "") {
		if (!found)
			exit 1
		print value
	}
}
