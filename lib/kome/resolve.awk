# SPDX-License-Identifier: GPL-3.0-or-later
#
# resolve.awk — turn a preset's entries into KOME_* assignments. Needs
# color.awk loaded first. Input: `ini_dump palette style preset` output
# (Section.key=value lines, in that order, so later files override).
#
#   -v preset=NAME   preset name (for messages and KOME_PRESET)
#   -v pfile=… -v sfile=… -v rfile=…   palette, style and preset paths
#
# Output: KOME_PRESET=NAME, then one KOME_KEY=value line per key. Keys must
# be lowercase snake_case; every palette role must be present and a colour.
# Errors go to stderr; exit 65 (EX_DATAERR).

function fail(msg) {
	printf "kome: error: %s\n", msg | "cat 1>&2"
	failed = 1
	exit 65
}

BEGIN {
	nroles = split("rosewater flamingo pink mauve red maroon peach yellow " \
		"green teal sky sapphire blue lavender text subtext1 subtext0 " \
		"overlay2 overlay1 overlay0 surface2 surface1 surface0 base mantle " \
		"crust accent", roles, " ")
	file["Palette"] = pfile
	file["Style"] = sfile
	file["Preset"] = rfile
}

{
	eq = index($0, "=")
	id = substr($0, 1, eq - 1)
	val = substr($0, eq + 1)
	dot = index(id, ".")
	section = substr(id, 1, dot - 1)
	key = substr(id, dot + 1)

	if (!(section in file))
		fail("unexpected section [" section "] (expected [Palette], [Style] or [Preset])")
	if (key == "Format")
		next
	if (key !~ /^[a-z][a-z0-9_]*$/)
		fail(file[section] ": key '" key "' must be lowercase snake_case, e.g. 'font_ui'")
	if (section == "Palette") {
		if (!color_valid(val))
			fail(file[section] ": " key "=" val " is not a colour (#rrggbb)")
		have[key] = 1
	}

	var = "KOME_" toupper(key)
	if (!(var in value))
		order[++n] = var
	value[var] = val
}

END {
	if (failed)
		exit 65
	for (i = 1; i <= nroles; i++)
		if (!(roles[i] in have))
			fail(pfile ": palette role '" roles[i] "' is missing")
	print "KOME_PRESET=" preset
	for (i = 1; i <= n; i++)
		print order[i] "=" value[order[i]]
}
