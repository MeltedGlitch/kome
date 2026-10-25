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

MAN = doc/man/kome.1 doc/man/kome.conf.5

SCRIPTS = bin/kome lib/kome/*.sh libexec/kome/kome-* libexec/kome/units/*/unit

all:
	@echo "Nothing to build. Run 'make install' (PREFIX=$(PREFIX))."

# lib/kome, libexec/kome and share/kome hold only kome's own files: replace
# them whole, so files removed or renamed since the last install (e.g. a unit
# that moved to another NN-) do not linger and run twice. The launcher entry
# runs kome by its full path: ~/.local/bin is not on every session's PATH.
install:
	rm -rf $(DEST)/lib/kome $(DEST)/libexec/kome $(DEST)/share/kome
	install -Dm755 bin/kome $(DEST)/bin/kome
	find lib/kome share/kome -type f | while IFS= read -r f; do \
		install -Dm644 "$$f" "$(DEST)/$$f" || exit; done
	find libexec/kome -type f | while IFS= read -r f; do \
		if [ -x "$$f" ]; then m=755; else m=644; fi; \
		install -Dm$$m "$$f" "$(DEST)/$$f" || exit; done

	install -Dm644 doc/man/kome.1 $(DEST)/share/man/man1/kome.1
	install -Dm644 doc/man/kome.conf.5 $(DEST)/share/man/man5/kome.conf.5
	install -Dm644 completions/bash/kome $(DEST)/share/bash-completion/completions/kome
	install -Dm644 completions/zsh/_kome $(DEST)/share/zsh/site-functions/_kome
	install -Dm644 completions/fish/kome.fish $(DEST)/share/fish/vendor_completions.d/kome.fish
	mkdir -p $(DEST)/share/applications
	sed 's|^Exec=kome |Exec=$(PREFIX)/bin/kome |' share/applications/kome.desktop \
		>$(DEST)/share/applications/kome.desktop

uninstall:
	rm -f $(DEST)/bin/kome
	rm -f $(DEST)/share/man/man1/kome.1 $(DEST)/share/man/man5/kome.conf.5
	rm -f $(DEST)/share/bash-completion/completions/kome
	rm -f $(DEST)/share/zsh/site-functions/_kome
	rm -f $(DEST)/share/fish/vendor_completions.d/kome.fish
	rm -f $(DEST)/share/applications/kome.desktop
	rm -rf $(DEST)/lib/kome $(DEST)/libexec/kome $(DEST)/share/kome

lint:
	shellcheck -x $(SCRIPTS)
	shellcheck -s bash completions/bash/kome

test:
	bats tests

check: lint test

# Man pages are shipped pre-generated; regenerate them after editing the
# .scd sources (needs scdoc).
man: $(MAN)

doc/man/kome.1: doc/man/kome.1.scd
	scdoc <doc/man/kome.1.scd >doc/man/kome.1

doc/man/kome.conf.5: doc/man/kome.conf.5.scd
	scdoc <doc/man/kome.conf.5.scd >doc/man/kome.conf.5

.PHONY: all install uninstall lint test check man
