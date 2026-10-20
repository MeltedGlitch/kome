# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome installs per user by default (no root). System-wide:
#   sudo make install PREFIX=/usr/local
# Packagers: DESTDIR=/path/to/staging

PREFIX ?= $(HOME)/.local

BINDIR     = $(DESTDIR)$(PREFIX)/bin
LIBDIR     = $(DESTDIR)$(PREFIX)/lib/kome
LIBEXECDIR = $(DESTDIR)$(PREFIX)/libexec/kome

SCRIPTS = bin/kome lib/kome/common.sh

all:
	@echo "Nothing to build. Run 'make install' (PREFIX=$(PREFIX))."

install:
	install -Dm755 bin/kome $(BINDIR)/kome
	install -Dm644 lib/kome/common.sh $(LIBDIR)/common.sh

uninstall:
	rm -f $(BINDIR)/kome
	rm -rf $(LIBDIR) $(LIBEXECDIR)

lint:
	shellcheck -x $(SCRIPTS)

test:
	bats tests

check: lint test

.PHONY: all install uninstall lint test check
