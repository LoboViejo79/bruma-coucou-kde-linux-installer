#!/usr/bin/env bash
# Restaura la configuración guardada por install.sh (paneles, tema, atajos, GTK…).
# Uso: restore.sh            restaura la copia MÁS ANTIGUA (el estado anterior a Windows 11)
#      restore.sh --list     muestra las copias disponibles
#      restore.sh AAAAMMDD-HHMMSS
# No desinstala temas ni la app Configuración; el inicio de sesión se revierte con
# sudo login-win11.sh --revert
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
BK="$HERE/../backup"

mapfile -t ALL < <(ls -1d "$BK"/[0-9]*-[0-9]* 2>/dev/null | sort)
[ ${#ALL[@]} -gt 0 ] || { echo "No hay copias de seguridad en $BK"; exit 1; }

case "${1:-}" in
  --list) for d in "${ALL[@]}"; do echo "$(basename "$d")  ($(ls "$d" | tr '\n' ' '))"; done; exit 0 ;;
  "") B=${ALL[0]} ;;
  *) B="$BK/$1"; [ -d "$B" ] || { echo "No existe la copia $1 (usa --list)"; exit 1; } ;;
esac
echo "==> Restaurando $(basename "$B")"

# Plasma reescribe su configuración al salir: se detiene antes de copiar
kquitapp6 plasmashell >/dev/null 2>&1 || true
# El Explorador también guarda su configuración al cerrarse
for s in $(qdbus6 2>/dev/null | grep -E '^ ?org\.kde\.dolphin' || true); do qdbus6 "$s" /MainApplication quit >/dev/null 2>&1 || true; done
for f in "$B"/*; do
  n=$(basename "$f")
  # el panel lateral del Explorador vive en ~/.local/share; el resto en ~/.config
  [ "$n" = user-places.xbel ] && dst=~/.local/share/$n || dst=~/.config/$n
  rm -rf "$dst"
  cp -a "$f" "$dst"
  echo "   $n"
done
# Barras del Explorador y vista por defecto de carpetas (explorer.sh)
rm -f ~/.local/share/kxmlgui5/dolphin/dolphinui.rc ~/.local/share/dolphin/view_properties/global/.directory \
      ~/.local/bin/dolphin ~/.config/systemd/user/plasma-dolphin.service.d/win11.conf \
      ~/.local/share/locale/es/LC_MESSAGES/kio6.mo
rm -rf ~/.local/opt/dolphin-win11   # Dolphin parcheado (build-dolphin.sh)
rm -f ~/.local/share/kio/servicemenus/win11-openwith.desktop   # "Elegir otra aplicación"
rm -f ~/.local/share/icons/hicolor/scalable/places/win11-*.svg   # iconos a color del panel lateral
systemctl --user daemon-reload 2>/dev/null || true
# Vista guardada de Inicio (sin vistas previas)
python3 -I -c 'import os; os.removexattr(os.path.expanduser("~"), "user.kde.fm.viewproperties#1")' 2>/dev/null || true

# Quita la redirección de "Preferencias del sistema" a la app Configuración
rm -f ~/.local/share/applications/systemsettings.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true

kstart plasmashell >/dev/null 2>&1 &
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
echo "Listo. Cierra sesión y vuelve a entrar para que se apliquen fuentes, atajos y estilo de apps."
