# kome

*[Leer en español](README.es.md)*

**kome** (米, Japanese for uncooked rice) changes the whole look of
**KDE Plasma 6** in one command: colours, fonts, icons, cursor, window
decorations, GTK apps and the terminal — coherently, and fully reversible.

```sh
kome apply mocha        # Catppuccin Mocha everywhere
kome restore original   # back to exactly how your desktop was
```

> **Status:** early development. v0.1 is in progress; nothing is usable yet.

## Principles

- A small UNIX tool: plain shell, plain INI files, no daemons.
- Never needs root and never installs packages — it tells you what to install.
- Never overrides other programs or your own config; easy to remove completely.
- Works on any Linux distribution with Plasma 6.

## Install (from source)

```sh
git clone https://github.com/<user>/kome
cd kome
make install            # into ~/.local, no root needed
```

Make sure `~/.local/bin` is in your `PATH`. To remove it: `make uninstall`.

## Licence

GPL-3.0-or-later. Built on community themes, for the community.
