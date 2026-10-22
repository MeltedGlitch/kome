# SPDX-License-Identifier: GPL-3.0-or-later
#
# contrast.awk — rate a resolved preset's text pairs. Needs color.awk loaded
# first. Input: KOME_KEY=value lines (preset_resolve's output). The pairs
# come from the environment, PAIRS="<fg role>/<bg role>/<what>" one per line.
# Output, per pair: "  <pass|warn|fail>  <ratio>:1  <fg> on <bg>  (<what>)".

{
	eq = index($0, "=")
	key = tolower(substr($0, 6, eq - 6))
	value[key] = substr($0, eq + 1)
}

END {
	n = split(ENVIRON["PAIRS"], pairs, "\n")
	for (i = 1; i <= n; i++) {
		if (split(pairs[i], p, "/") < 3)
			continue
		c = color_contrast(value[p[1]], value[p[2]])
		verdict = c >= 4.5 ? "pass" : c >= 3 ? "warn" : "fail"
		printf "  %s  %5.2f:1  %s on %s  (%s)\n", verdict, c, p[1], p[2], p[3]
	}
}
