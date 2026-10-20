# kome

*[Read in English](README.md)*

**kome** (米, «arroz crudo» en japonés) cambia todo el aspecto de
**KDE Plasma 6** con un solo comando: colores, fuentes, iconos, cursor,
decoración de ventanas, apps GTK y la terminal — de forma coherente y
totalmente reversible.

```sh
kome apply mocha        # Catppuccin Mocha en todas partes
kome restore original   # vuelve exactamente a como tenías tu escritorio
```

> **Estado:** desarrollo temprano. La v0.1 está en curso; aún no se puede usar.

## Principios

- Una herramienta UNIX pequeña: shell, archivos INI, sin demonios.
- Nunca necesita root ni instala paquetes: te dice qué instalar.
- Nunca pisa otros programas ni tu configuración; se quita por completo fácilmente.
- Funciona en cualquier distribución Linux con Plasma 6.

## Instalación (desde el código)

```sh
git clone https://github.com/<user>/kome
cd kome
make install            # en ~/.local, sin root
```

Asegúrate de que `~/.local/bin` está en tu `PATH`. Para quitarlo: `make uninstall`.

## Licencia

GPL-3.0-or-later. Hecho sobre temas de la comunidad, para la comunidad.
