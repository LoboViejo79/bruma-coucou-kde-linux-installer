#!/usr/bin/env bash
# Parte de install-user.sh que corre como el usuario (sin sesión gráfica): ver install-user.sh
set -uo pipefail
K=/usr/share/kde-win11
mkdir -p ~/.config ~/.cache ~/.local/share/applications ~/.config/autostart

# Lo que abría "Preferencias del sistema" (favoritos, KRunner…) abre Configuración estilo Windows 11
printf '[Desktop Entry]\nType=Application\nName=Configuración\nExec=/usr/bin/win11-settings\nIcon=preferences-system\nNoDisplay=true\n' \
  > ~/.local/share/applications/systemsettings.desktop
# CachyOS Hello (menú) abre Bienvenido; su autoarranque se sustituye por el de Bienvenido
printf '[Desktop Entry]\nType=Application\nName=CachyOS Hello\nExec=/usr/bin/win11-welcome\nIcon=org.cachyos.hello\nNoDisplay=true\n' \
  > ~/.local/share/applications/cachyos-hello.desktop
rm -f ~/.config/autostart/cachyos-hello.desktop
# Administrador de tareas con Ctrl+Mayús+Esc (kglobalaccel lee el archivo al iniciar la sesión)
kwriteconfig6 --file kglobalshortcutsrc --group services --group win11-taskmgr.desktop --key _launch "Ctrl+Shift+Esc"

# Todo lo que apply.sh guarda en archivos (WIN11_OFFLINE: sin D-Bus ni Plasma en marcha)
bash "$K/scripts/apply.sh" light
# Barra de tareas, menú Inicio y fondo: los crea Plasma desde el diseño del tema global
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.win11.desktop
# El cursor también en las apps que leen la configuración antigua
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme Fluent-cursors

touch ~/.config/win11-seeded
echo "listo"
