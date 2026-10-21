# SPDX-License-Identifier: GPL-3.0-or-later
#
# kome installs per user by default (no root). System-wide:
#   sudo make install PREFIX=/usr/local
# Packagers: DESTDIR=/path/to/staging
#
# The repository has the same layout as an installation, so kome runs the
# same way from a checkout (./bin/kome) and from $(PREFIX).

PREFIX ?= $(HOME)/.local

DEST = $(DESTDIR)$(PREFIX)

SCRIPTS = bin/kome lib/kome/*.sh libexec/kome/kome-*

all:
	@echo "Nothing to build. Run 'make install' (PREFIX=$(PREFIX))."

install:
	install -Dm755 bin/kome $(DEST)/bin/kome
	find lib/kome share/kome -type f | while IFS= read -r f; do \
		install -Dm644 "$$f" "$(DEST)/$$f" || exit; done
	find libexec/kome -type f | while IFS= read -r f; do \
		if [ -x "$$f" ]; then m=755; else m=644; fi; \
		install -Dm$$m "$$f" "$(DEST)/$$f" || exit; done

uninstall:
	rm -f $(DEST)/bin/kome
	rm -rf $(DEST)/lib/kome $(DEST)/libexec/kome $(DEST)/share/kome

lint:
	shellcheck -x $(SCRIPTS)

test:
	bats tests

check: lint test

.PHONY: all install uninstall lint test check
