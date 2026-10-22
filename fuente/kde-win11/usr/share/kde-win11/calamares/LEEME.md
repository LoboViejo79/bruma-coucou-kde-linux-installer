# Instalador de CachyOS con aspecto de Windows 11

Para una ISO propia (cachyos-live-iso / archiso), copiar en el sistema en vivo:

- `branding/cachyos-win11/` → `/usr/share/calamares/branding/cachyos-win11/`
- `settings.conf` → `/usr/share/calamares/settings.conf` (y también como `settings_online.conf`)
- `modules/netinstall.conf` y `modules/netinstall.yaml` → `/etc/calamares/modules/`

Cambios respecto al original:

- Tema estilo Windows 11 (pasos a la izquierda, botón Siguiente azul, listas en tarjetas).
- Sin el paso "Escritorio": siempre se instala Plasma (grupo KDE-Desktop oculto y marcado).
- "Paquetes" sin los otros 18 escritorios; usa solo la lista local (no la de GitHub).
