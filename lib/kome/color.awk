# SPDX-License-Identifier: GPL-3.0-or-later
#
# color.awk — colour maths for kome templates. A library of functions only:
# load it next to another program with  LC_ALL=C awk -f color.awk -f program.awk
# (LC_ALL=C: some awks print decimals with the locale's separator, e.g. "0,5").
#
# Colours are always "#rrggbb" strings (input case-insensitive, output
# lowercase). Functions given an invalid colour return "" (or -1 for
# numbers); callers check with color_valid() first.
#
#   color_valid(c)        1 if c is #rrggbb, else 0
#   color_rgb(c)          "r,g,b" in 0..255 (KDE colour scheme format)
#   color_mix(a, b, t)    a blended towards b by t (0 = a, 1 = b)
#   color_lighten(c, t)   c blended towards white by t
#   color_darken(c, t)    c blended towards black by t
#   color_luminance(c)    WCAG 2 relative luminance, 0..1
#   color_contrast(a, b)  WCAG 2 contrast ratio, 1..21

function color_valid(c) {
	return c ~ /^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/
}

# Split c into ch[1..3] (0..255). Returns 0 if c is invalid.
function _color_split(c, ch,    i, hex) {
	if (!color_valid(c))
		return 0
	hex = tolower(substr(c, 2))
	for (i = 1; i <= 3; i++)
		ch[i] = _color_hexval(substr(hex, 2 * i - 1, 1)) * 16 + _color_hexval(substr(hex, 2 * i, 1))
	return 1
}

function _color_hexval(d) {
	return index("0123456789abcdef", d) - 1
}

# Round and clamp one channel, then format the colour.
function _color_join(r, g, b) {
	return sprintf("#%02x%02x%02x", _color_byte(r), _color_byte(g), _color_byte(b))
}

function _color_byte(v) {
	v = int(v + 0.5)
	return v < 0 ? 0 : v > 255 ? 255 : v
}

function color_rgb(c,    ch) {
	if (!_color_split(c, ch))
		return ""
	return ch[1] "," ch[2] "," ch[3]
}

function color_mix(a, b, t,    x, y) {
	if (!_color_split(a, x) || !_color_split(b, y))
		return ""
	return _color_join(x[1] + (y[1] - x[1]) * t, \
		x[2] + (y[2] - x[2]) * t, \
		x[3] + (y[3] - x[3]) * t)
}

function color_lighten(c, t) {
	return color_mix(c, "#ffffff", t)
}

function color_darken(c, t) {
	return color_mix(c, "#000000", t)
}

function color_luminance(c,    ch, i, v, lum) {
	if (!_color_split(c, ch))
		return -1
	for (i = 1; i <= 3; i++) {
		v = ch[i] / 255
		lum[i] = v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4
	}
	return 0.2126 * lum[1] + 0.7152 * lum[2] + 0.0722 * lum[3]
}

function color_contrast(a, b,    la, lb) {
	la = color_luminance(a)
	lb = color_luminance(b)
	if (la < 0 || lb < 0)
		return -1
	return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05)
}
