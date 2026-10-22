#!/usr/bin/env bash
# Pantalla de inicio de sesión estilo Windows 11.
# Plasma Login Manager no admite temas (su interfaz va compilada), así que se cambia a SDDM
# con el tema propio win11-login (sddm/win11-login). Necesita root.
# Uso: sudo ./login-win11.sh [light|dark]      sudo ./login-win11.sh --revert
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Ejecuta con sudo: sudo $0 ${1:-}"; exit 1; }

USR=${SUDO_USER:-$(logname)}
UHOME=$(getent passwd "$USR" | cut -d: -f6)

if [ "${1:-}" = "--revert" ]; then
  systemctl cat plasmalogin.service >/dev/null 2>&1 || { echo "plasmalogin.service no existe; se deja SDDM."; exit 1; }
  rm -f /etc/sddm.conf.d/10-win11.conf
  # -f reemplaza el alias display-manager.service: nunca queda el sistema sin gestor de inicio
  systemctl enable -f plasmalogin.service
  systemctl disable sddm.service 2>/dev/null || true
  echo "Restaurado Plasma Login Manager. Reinicia para aplicarlo."
  exit 0
fi

V=${1:-light}
case "$V" in light|dark) ;; *) echo "Uso: $0 [light|dark|--revert]"; exit 1 ;; esac
HERE=$(cd "$(dirname "$0")/.." && pwd)
SRC="$HERE/sddm/win11-login"
[ -d "$SRC" ] || { echo "No se encuentra $SRC"; exit 1; }

echo "==> Instalando SDDM"
pacman -S --needed --noconfirm sddm qt6-5compat qt6-svg qt6-declarative

echo "==> Tema win11-login ($V)"
T=/usr/share/sddm/themes/win11-login
rm -rf "$T"
cp -r "$SRC" "$T"
# Fondo: el de Windows 11 claro u oscuro, nítido para el bloqueo y desenfocado para el inicio de sesión
WP="$UHOME/.local/share/wallpapers/Win11OS-$V/contents/images/3840x2400.jpg"
if [ -f "$WP" ] && command -v magick >/dev/null; then
  magick "$WP" -resize 2560x1600 -quality 90 "$T/background.jpg"
  magick "$WP" -resize 640x400 -blur 0x14 -resize 2560x1600 -quality 88 "$T/background-blur.jpg"
fi

echo "==> Fuente Selawik para el login"
if [ -d "$UHOME/.local/share/fonts/Selawik" ]; then
  mkdir -p /usr/local/share/fonts/Selawik
  cp "$UHOME"/.local/share/fonts/Selawik/*.ttf /usr/local/share/fonts/Selawik/
  fc-cache -f >/dev/null
fi

echo "==> Foto de usuario"
if [ -f "$UHOME/.face.icon" ] || [ -f "$UHOME/.face" ]; then
  mkdir -p /var/lib/AccountsService/icons
  cp "$( [ -f "$UHOME/.face.icon" ] && echo "$UHOME/.face.icon" || echo "$UHOME/.face")" "/var/lib/AccountsService/icons/$USR"
fi

echo "==> Configuración de SDDM (greeter en Wayland con KWin, como la sesión)"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-win11.conf <<EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1

[Theme]
Current=win11-login
Font=Selawik,11
CursorTheme=$( [ "$V" = dark ] && echo Fluent-dark-cursors || echo Fluent-cursors )

[Users]
RememberLastUser=true
RememberLastSession=true
EOF
# Los cursores Fluent están en el home del usuario; se copian para que el greeter los vea
for c in Fluent-cursors Fluent-dark-cursors; do
  [ -d "$UHOME/.local/share/icons/$c" ] && rm -rf "/usr/share/icons/$c" && cp -r "$UHOME/.local/share/icons/$c" /usr/share/icons/
  [ -d "$UHOME/.icons/$c" ] && rm -rf "/usr/share/icons/$c" && cp -r "$UHOME/.icons/$c" /usr/share/icons/
done

echo "==> Cambiando de Plasma Login Manager a SDDM"
# Primero se activa SDDM (-f reemplaza el alias display-manager.service) y solo después se
# desactiva el anterior, que puede no existir: si algo falla, sigue habiendo gestor de inicio.
systemctl enable -f sddm.service
systemctl disable plasmalogin.service 2>/dev/null || true

echo "Listo. Reinicia el equipo para ver el nuevo inicio de sesión."
echo "Para volver al anterior: sudo $0 --revert"
