# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Repository skeleton: dispatcher (`kome --help`, `kome --version`),
  shared helpers, Makefile (per-user install by default), CI, licence.
- INI reader for kome's own files (`lib/kome/ini.awk`, `ini_get`,
  `ini_dump`): strict, no inline comments, `FILE:LINE` errors.
- Colour engine (`lib/kome/color.awk`): validate, `r,g,b`, mix,
  lighten, darken, WCAG luminance and contrast.

### Fixed

- awk always runs with `LC_ALL=C`, so decimals never come out as `0,5`
  on systems with a non-English locale.
