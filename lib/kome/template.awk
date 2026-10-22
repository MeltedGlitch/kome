# SPDX-License-Identifier: GPL-3.0-or-later
#
# template.awk — fill a kome template. Needs color.awk loaded first:
#
#   LC_ALL=C awk -f color.awk -f template.awk TEMPLATE
#
# Values come from the environment: {{name}} reads KOME_NAME.
#
#   {{name}}            the value, verbatim
#   {{name:hex}}        a colour, as #rrggbb
#   {{name:rgb}}        a colour, as r,g,b (KDE)
#   {{mix(a,b,t)}}      a blended towards b by t
#   {{lighten(a,t)}}    a blended towards white by t
#   {{darken(a,t)}}     a blended towards black by t
#   {{by_mode(a,b)}}    a for dark looks, b for light ones (KOME_MODE); a and
#                       b are colours, or plain numbers (returned as is)
#
# Function arguments are names or #rrggbb literals; t is a number from 0 to
# 1. Functions default to :hex. Spaces inside {{ }} are ignored. Text outside
# {{ }} is copied as is. Any error prints FILE:LINE and exits 65 (EX_DATAERR);
# output is then incomplete, so callers must not use it.

function fail(msg) {
	printf "kome: error: %s:%d: %s\n", FILENAME, FNR, msg | "cat 1>&2"
	failed = 1
	exit 65
}

function value(name,    var) {
	if (name !~ /^[a-z][a-z0-9_]*$/)
		fail("invalid name '" name "' in {{ }}")
	var = "KOME_" toupper(name)
	if (!(var in ENVIRON))
		fail("unknown value '" name "' (" var " is not set)")
	return ENVIRON[var]
}

function colour(arg,    c) {
	c = arg ~ /^#/ ? arg : value(arg)
	if (!color_valid(c))
		fail("'" arg "' is not a colour (#rrggbb)")
	return c
}

function amount(arg) {
	if (arg !~ /^(0|1|1\.0*|0?\.[0-9]+|0\.[0-9]*)$/)
		fail("'" arg "' is not a number from 0 to 1")
	return arg + 0
}

# mode_value <arg> — a number literal as is, else a colour.
function mode_value(arg) {
	if (arg ~ /^-?[0-9]+(\.[0-9]+)?$/)
		return arg
	return colour(arg)
}

function call(fn, args,    a, n) {
	n = split(args, a, ",")
	if (fn == "mix") {
		if (n != 3)
			fail("mix() takes 3 arguments: mix(a,b,t)")
		return color_mix(colour(a[1]), colour(a[2]), amount(a[3]))
	}
	if (fn == "lighten" || fn == "darken") {
		if (n != 2)
			fail(fn "() takes 2 arguments: " fn "(a,t)")
		if (fn == "lighten")
			return color_lighten(colour(a[1]), amount(a[2]))
		return color_darken(colour(a[1]), amount(a[2]))
	}
	if (fn == "by_mode") {
		if (n != 2)
			fail("by_mode() takes 2 arguments: by_mode(dark,light)")
		if (ENVIRON["KOME_MODE"] == "light")
			return mode_value(a[2])
		if (ENVIRON["KOME_MODE"] == "dark")
			return mode_value(a[1])
		fail("by_mode() needs mode=dark or mode=light in the preset")
	}
	fail("unknown function '" fn "()'")
}

function expand(expr,    fmt, p, v) {
	gsub(/[ \t]/, "", expr)
	fmt = ""
	p = index(expr, ":")
	if (p) {
		fmt = substr(expr, p + 1)
		expr = substr(expr, 1, p - 1)
	}
	if (expr ~ /^[a-z_]+\(.*\)$/) {
		p = index(expr, "(")
		v = call(substr(expr, 1, p - 1), substr(expr, p + 1, length(expr) - p - 1))
		if (fmt == "" && color_valid(v))
			fmt = "hex"
	} else
		v = value(expr)

	if (fmt == "")
		return v
	if (!color_valid(v))
		fail("'" expr "' is not a colour, so it has no :" fmt " format")
	if (fmt == "hex")
		return tolower(v)
	if (fmt == "rgb")
		return color_rgb(v)
	fail("unknown format ':" fmt "' (use :hex or :rgb)")
}

{
	out = ""
	rest = $0
	while ((p = index(rest, "{{")) > 0) {
		out = out substr(rest, 1, p - 1)
		rest = substr(rest, p + 2)
		q = index(rest, "}}")
		if (q == 0)
			fail("'{{' is not closed on this line")
		out = out expand(substr(rest, 1, q - 1))
		rest = substr(rest, q + 2)
	}
	print out rest
}

END {
	if (failed)
		exit 65
}
